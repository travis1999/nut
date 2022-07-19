const std = @import("std");
const vm = @import("vm.zig");
const chunk = @import("chunk.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const ScannerError = error{ UnexpectedCharacter, UnterminatedString, InvalidCharacter, InvalidNumber };

pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

const map = std.ComptimeStringMap(TokenType, .{
    .{ "and", .AND },
    .{ "class", .CLASS },
    .{ "else", .ELSE },
    .{ "false", .FALSE },
    .{ "for", .FOR },
    .{ "fun", .FUN },
    .{ "if", .IF },
    .{ "nil", .NIL },
    .{ "or", .OR },
    .{ "print", .PRINT },
    .{ "return", .RETURN },
    .{ "super", .SUPER },
    .{ "this", .THIS },
    .{ "true", .TRUE },
    .{ "var", .VAR },
    .{ "while", .WHILE },
});

test "test map" {
    print("why {}\n", .{map.get("class")});
}

pub const Token = struct { t_type: TokenType, value: []u8, line: usize };

pub const Scanner = struct {
    source: []u8,
    start: usize = 0,
    current: usize = 0,
    line: usize = 1,

    pub fn init(source: []u8) Scanner {
        return Scanner{ .source = source };
    }

    pub fn scan_token(self: *Scanner) Token {
        self.skip_whitespace() catch {
            self.token_error("bad token");
            return self.error_token();
        };

        self.start = self.current;

        if (self.is_at_end()) {
            return self.make_token(TokenType.EOF);
        }

        var c = self.advance();

        if (self.is_digit(c)) return self.number();
        if (self.is_alpha(c)) return self.identifier();

        switch (c) {
            '(' => return self.make_token(.LEFT_PAREN),
            ')' => return self.make_token(.RIGHT_PAREN),
            '{' => return self.make_token(.LEFT_BRACE),
            '}' => return self.make_token(.RIGHT_BRACE),
            ';' => return self.make_token(.SEMICOLON),
            ',' => return self.make_token(.COMMA),
            '.' => return self.make_token(.DOT),
            '-' => return self.make_token(.MINUS),
            '+' => return self.make_token(.PLUS),
            '/' => return self.make_token(.SLASH),
            '*' => return self.make_token(.STAR),
            '!' => return self.two_char('=', .BANG_EQUAL, .BANG),
            '=' => return self.two_char('=', .EQUAL_EQUAL, .EQUAL),
            '<' => return self.two_char('=', .LESS_EQUAL, .LESS),
            '>' => return self.two_char('=', .GREATER_EQUAL, .GREATER),
            '"' => return self.string(),
            else => self.token_error("Unexpected character"),
        }

        self.token_error("Unexpected character");
        return self.error_token();
    }

    fn token_error(self: *Scanner, message: []const u8) void {
        print("Error at line: {}, {s}, '{c}'", .{ self.line, message, self.source[self.current - 1] });
        std.os.exit(98);
    }

    fn two_char(self: *Scanner, expected: u8, t_exp: TokenType, t_found: TokenType) Token {
        if (self.match(expected)) {
            return self.make_token(t_exp);
        }
        return self.make_token(t_found);
    }

    fn string(self: *Scanner) Token {
        while (self.peek() != '"' and !self.is_at_end()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.is_at_end()) {
            self.token_error("Unterminated string");
            return self.error_token();
        }

        _ = self.advance();
        return self.make_token(.STRING);
    }

    fn is_digit(_: *Scanner, c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn is_alpha(_: *Scanner, c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn identifier_type(self: *Scanner) TokenType {
        if (map.has(self.source[self.start..self.current])) {
            return map.get(self.source[self.start..self.current]).?;
        }
        return .IDENTIFIER;
    }

    fn identifier(self: *Scanner) Token {
        while (self.is_alpha(self.peek()) or self.is_digit(self.peek())) {
            _ = self.advance();
        }

        var t_type = self.identifier_type();
        return self.make_token(t_type);
    }

    fn number(self: *Scanner) Token {
        while (self.is_digit(self.peek())) {
            _ = self.advance();
        }

        if (self.peek() == '.' and self.is_digit(self.peek_next())) {
            _ = self.advance();
            while (self.is_digit(self.peek())) _ = self.advance();
        }

        return self.make_token(.NUMBER);
    }

    fn peek(self: *Scanner) u8 {
        if (self.is_at_end()) return 0;
        return self.source[self.current];
    }

    fn skip_whitespace(self: *Scanner) !void {
        while (!self.is_at_end()) {
            var c = self.peek();
            switch (c) {
                ' ', '\r', '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '\\' => {
                    if (self.peek_next() == '\\') {
                        while (!self.is_at_end() and self.peek() != '\n') _ = self.advance();
                    } else {
                        return ScannerError.UnexpectedCharacter;
                    }
                },
                else => return,
            }
        }
    }

    fn peek_next(self: *Scanner) u8 {
        if (self.current + 1 == self.source.len) {
            return 0;
        }

        return self.source[self.current + 1];
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.is_at_end()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn make_token(self: *Scanner, t_type: TokenType) Token {
        return Token{ .t_type = t_type, .value = self.source[self.start..self.current], .line = self.line };
    }

    fn error_token(self: *Scanner) Token {
        return Token{ .t_type = TokenType.ERROR, .value = "", .line = self.line };
    }

    fn is_at_end(self: *Scanner) bool {
        return self.current == self.source.len;
    }
};
