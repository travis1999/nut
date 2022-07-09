const std = @import("std");
const vm = @import("vm.zig");
const chunk = @import("chunk.zig");
const Value = @import("value.zig").Value;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const scanner = @import("scanner.zig");
const TokenType = scanner.TokenType;
const Token = scanner.Token;
const print = std.debug.print;

const generator = @import("generator.zig");
const Generator = generator.Generator;

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
};

const ParseFn = fn (self: *Parser) anyerror!void;

const ParseRule = struct { prefix: ?ParseFn, infix: ?ParseFn, precedence: Precedence };

pub const Parser = struct {
    allocator: Allocator,
    scanner: *scanner.Scanner,
    haserror: bool = false,
    panic_mode: bool = false,
    generator: *Generator,
    current: ?Token = null,
    previous: ?Token = null,
    rules: [40]ParseRule = [_]ParseRule{
        .{ .prefix=grouping, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=unary, .infix=binary, .precedence=.TERM },
        .{ .prefix=null, .infix=binary, .precedence=.TERM },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=binary, .precedence=.FACTOR },
        .{ .prefix=null, .infix=binary, .precedence=.FACTOR },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=number, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
        .{ .prefix=null, .infix=null, .precedence=.NONE },
    },

    pub fn init(allocator: Allocator, scan: *scanner.Scanner, gen: *Generator) Parser {
        return Parser{
            .allocator = allocator,
            .scanner = scan,
            .generator = gen,
        };
    }

    fn advance(self: *Parser) !void {
        self.previous = self.current;

        while (true) {
            self.current = try self.scanner.scan_token();

            if (self.current) |current| {
                if (current.t_type != TokenType.ERROR) {
                    break;
                }
                self.error_at_current(current.value);
            }
        }
    }

    fn error_at_current(self: *Parser, message: []const u8) void {
        self.error_at(&self.current.?, message);
    }

    fn error_at(self: *Parser, token: *Token, message: []const u8) void {
        self.panic_mode = true;

        if (self.panic_mode) return;
        print("[line {d}] Error: ", .{token.line});

        if (token.t_type == TokenType.EOF) {
            print(" at end", .{});
        } else {
            print(" at '{s}'", .{token.value});
        }

        print(": {s}\n", .{message});
        self.haserror = true;
    }

    fn consume(self: *Parser, t_type: TokenType, message: []const u8) !?*Token {
        if (self.current.?.t_type == t_type) {
            try self.advance();
            return &self.previous.?;
        }
        self.error_at_current(message);
        return null;
    }

    fn return_(self: *Parser) void {
        self.generator.emit_return(self.current.?.line);
    }

    fn number(self: *Parser) !void {
        print("Float is {s}, {} {}\n", .{self.current.?.value, self.current.?, self.previous.?});
        var value = try std.fmt.parseFloat(f64, self.previous.?.value);
        var val = try Value.number_new(self.allocator, value);
        try self.generator.emit_constant(val, self.previous.?.line);
    }

    fn grouping(self: *Parser) !void {
        try self.expression();
        _ = try self.consume(TokenType.RIGHT_PAREN, "expect ')' after expression");
    }

    fn unary(self: *Parser) !void {
        var previous_type = self.previous.?.t_type;
        try self.expression();
        try self.parse_precedence(.UNARY);

        try switch (previous_type) {
            .MINUS => self.generator.write_opcode(chunk.OpCode.NEGATE, self.current.?.line),
            else => unreachable,
        };
    }

    fn expression(self: *Parser) !void {
        try self.parse_precedence(.ASSIGNMENT);
    }

    fn binary(self: *Parser) !void {
        var _type = self.previous.?.t_type;
        var rule = self.get_rule(_type);

        try self.parse_precedence(@intToEnum(Precedence, @enumToInt(rule.precedence) + 1));

        try switch (_type) {
            .PLUS => self.generator.write_opcode(chunk.OpCode.ADD, self.previous.?.line),
            .MINUS => self.generator.write_opcode(chunk.OpCode.SUB, self.previous.?.line),
            .STAR => self.generator.write_opcode(chunk.OpCode.MULTIPLY, self.previous.?.line),
            .SLASH => self.generator.write_opcode(chunk.OpCode.DIVIDE, self.previous.?.line),
            else => unreachable,
        };
    }

    fn get_rule(self: *Parser, _type: TokenType) ParseRule {
        return self.rules[@enumToInt(_type)];
    }

    fn parse_precedence(self: *Parser, prec: Precedence) !void {
        try self.advance();

        var prefix_rule = self.get_rule(self.previous.?.t_type).prefix;
        if (prefix_rule) |rule| {
            try rule(self);

            while (@enumToInt(prec) <= @enumToInt(self.get_rule(self.current.?.t_type).precedence)) {
                try self.advance();
                var infixrule = self.get_rule(self.previous.?.t_type).infix;
                if (infixrule) |rule_2| {
                    try rule_2(self);
                }
            }
        } else {
            self.error_at_current("Expected expression");
        }
    }

    pub fn parse(self: *Parser) !void {
        try self.advance();
        try self.expression();
    }
};
