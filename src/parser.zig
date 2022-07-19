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

const ParserError = error{
    SyntaxError,
};

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

const ParseFn = fn (self: *Parser) void;

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
        .{ .prefix = grouping, .infix = null, .precedence = .NONE }, // LEFT_PAREN]
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // RIGHT_PAREN
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // LEFT_BRACE
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // RIGHT_BRACE
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // COMMA
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // DOT
        .{ .prefix = unary, .infix = binary, .precedence = .TERM }, // MINUS
        .{ .prefix = null, .infix = binary, .precedence = .TERM }, // PLUS
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // SEMICOLON
        .{ .prefix = null, .infix = binary, .precedence = .FACTOR }, // SLASH
        .{ .prefix = null, .infix = binary, .precedence = .FACTOR }, // STAR
        .{ .prefix = unary, .infix = null, .precedence = .NONE }, // BANG
        .{ .prefix = null, .infix = binary, .precedence = .EQUALITY }, // BANG_EQUAL
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // EQUAL
        .{ .prefix = null, .infix = binary, .precedence = .EQUALITY }, // EQUAL_EQUAL
        .{ .prefix = null, .infix = binary, .precedence = .COMPARISON }, // GREATER
        .{ .prefix = null, .infix = binary, .precedence = .COMPARISON }, // GREATER_EQUAL
        .{ .prefix = null, .infix = binary, .precedence = .COMPARISON }, // LESS
        .{ .prefix = null, .infix = binary, .precedence = .COMPARISON }, // LESS_EQUAL
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // IDENTIFIER
        .{ .prefix = string, .infix = null, .precedence = .NONE }, // STRING
        .{ .prefix = number, .infix = null, .precedence = .NONE }, // NUMBER
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // AND
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // CLASS
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // ELSE
        .{ .prefix = literal, .infix = null, .precedence = .NONE }, // FALSE
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // FOR
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // FUN
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // IF
        .{ .prefix = literal, .infix = null, .precedence = .NONE }, // NIL
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // OR
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // PRINT
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // RETURN
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // SUPER
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // THIS
        .{ .prefix = literal, .infix = null, .precedence = .NONE }, // TRUE
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // VAR
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // WHILE
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // ERROR
        .{ .prefix = null, .infix = null, .precedence = .NONE }, // EOF
    },

    pub fn init(allocator: Allocator, scan: *scanner.Scanner, gen: *Generator) Parser {
        return Parser{
            .allocator = allocator,
            .scanner = scan,
            .generator = gen,
        };
    }

    fn advance(self: *Parser) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scan_token();

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

    fn literal(self: *Parser) void {
        switch (self.previous.?.t_type) {
            .FALSE => self.generator.write_opcode(.FALSE, self.previous.?.line),
            .NIL => self.generator.write_opcode(.NIL, self.previous.?.line),
            .TRUE => self.generator.write_opcode(.TRUE, self.previous.?.line),
            else => unreachable,
        }
    }

    fn string(self: *Parser) void {
        var tok = self.previous.?;
        _ = self.generator.emit_constant(Value.value_new(self.allocator, tok.value[1 .. tok.value.len - 1]), tok.line);
    }

    fn error_at(self: *Parser, token: *Token, message: []const u8) void {
        if (self.panic_mode) return;
        print("[line {d}] Error ", .{token.line});

        if (token.t_type == TokenType.EOF) {
            print("at EOF", .{});
        } else {
            print("at '{s}'", .{token.value});
        }

        print("{s} \n", .{message});
        self.panic_mode = true;

        self.haserror = true;
    }

    fn consume(self: *Parser, t_type: TokenType, message: []const u8) ?*Token {
        if (self.current.?.t_type == t_type) {
            self.advance();
            return &self.previous.?;
        }
        self.error_at_current(message);
        return null;
    }

    fn return_(self: *Parser) void {
        self.generator.emit_return(self.current.?.line);
    }

    fn number(self: *Parser) void {
        var value = std.fmt.parseFloat(f64, self.previous.?.value) catch {
            // parse float should never fail as the string is validated while
            // scanning
            unreachable;
        };

        var val = Value.number_new(self.allocator, value);
        _ = self.generator.emit_constant(val, self.previous.?.line);
    }

    fn grouping(self: *Parser) void {
        self.expression();
        _ = self.consume(TokenType.RIGHT_PAREN, "expect ')' after expression");
    }

    fn unary(self: *Parser) void {
        var previous_type = self.previous.?.t_type;
        self.parse_precedence(.UNARY);

        switch (previous_type) {
            .MINUS => self.generator.write_opcode(chunk.OpCode.NEGATE, self.current.?.line),
            .BANG => self.generator.write_opcode(chunk.OpCode.NOT, self.current.?.line),
            else => unreachable,
        }
    }

    fn expression(self: *Parser) void {
        self.parse_precedence(.ASSIGNMENT);
    }

    fn emit_byte(self: *Parser, opcode: chunk.OpCode) void {
        self.generator.write_opcode(opcode, self.previous.?.line);
    }

    fn emit_bytes(self: *Parser, op0: chunk.OpCode, op1: chunk.OpCode) void {
        self.emit_byte(op0);
        self.emit_byte(op1);
    }

    fn binary(self: *Parser) void {
        var _type = self.previous.?.t_type;
        var rule = self.get_rule(_type);

        self.parse_precedence(@intToEnum(Precedence, @enumToInt(rule.precedence) + 1));

        switch (_type) {
            .BANG_EQUAL => self.emit_bytes(.EQUAL, .NOT),
            .EQUAL_EQUAL => self.emit_byte(.EQUAL),
            .GREATER => self.emit_byte(.GREATER),
            .GREATER_EQUAL => self.emit_bytes(.LESS, .NOT),
            .LESS => self.emit_byte(.LESS),
            .LESS_EQUAL => self.emit_bytes(.GREATER, .NOT),
            .PLUS => self.emit_byte(.ADD),
            .MINUS => self.emit_byte(.SUB),
            .STAR => self.emit_byte(.MULTIPLY),
            .SLASH => self.emit_byte(.DIVIDE),
            else => unreachable,
        }
    }

    fn get_rule(self: *Parser, _type: TokenType) ParseRule {
        return self.rules[@enumToInt(_type)];
    }

    fn parse_precedence(self: *Parser, prec: Precedence) void {
        self.advance();

        var prefix_rule = self.get_rule(self.previous.?.t_type).prefix;
        if (prefix_rule) |rule| {
            rule(self);

            while (@enumToInt(prec) <= @enumToInt(self.get_rule(self.current.?.t_type).precedence)) {
                self.advance();
                var infixrule = self.get_rule(self.previous.?.t_type).infix;
                if (infixrule) |rule_2| {
                    rule_2(self);
                }
            }
        } else {
            self.error_at_current("Expected expression");
        }
    }

    fn check(self: *Parser, t_type: TokenType) bool {
        return self.current.?.t_type == t_type;
    }

    fn match(self: *Parser, t_type: TokenType) bool {
        if (self.check(t_type)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn declaration(self: *Parser) void {
        if (self.match(.VAR)) {
            self.var_declaration();
        } else {
            self.statement();
        }
    }

    fn sync(self: *Parser) void {
        self.panic_mode = false;

        while (self.current.?.t_type != .EOF) {
            if (self.previous.?.type == .SEMICOLON) return;

            switch (self.current.?.t_type) {
                .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .RETURN, .PRINT => return,
                else => {},
            }

            self.advance();
        }
    }

    fn var_declaration(self: *Parser) void {
        var glob = self.parse_variable("Expected Variable Name");

        if (self.match(.EQUAL)) {
            self.expression();
        } else {
            self.emit_byte(.NIL);
        }

        _ = self.consume(.SEMICOLON, "Expected ';' after variable declaration");
        self.generator.define_variable(glob, self.previous.?.line);
    }

    fn parse_variable(self: *Parser, error_msg: []const u8) usize {
        _ = self.consume(.IDENTIFIER, error_msg);
        return self.identifier_constant(self.previous.?);
    }

    fn identifier_constant(self: *Parser, token: Token) usize {
        return self.generator.emit_constant(Value.value_new(self.allocator, token.value), token.line);
    }

    fn statement(self: *Parser) void {
        if (self.match(TokenType.PRINT)) {
            self.print_statement();
        } else {
            self.expression_statement();
        }
    }

    fn expression_statement(self: *Parser) void {
        self.expression();
        _ = self.consume(TokenType.SEMICOLON, "Expected ';' after expression");
        self.emit_byte(chunk.OpCode.POP);
    }

    fn print_statement(self: *Parser) void {
        self.expression();
        _ = self.consume(TokenType.SEMICOLON, "Expect ';' after value");
        self.emit_byte(chunk.OpCode.PRINT);
    }

    pub fn parse(self: *Parser) void {
        self.advance();

        while (!self.match(.EOF)) {
            self.declaration();
        }

        print("we got here", .{});

        self.return_();
    }
};
