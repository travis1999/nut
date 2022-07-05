import string
from nuttoken import Token, TokenType
from utils import Span, Context
from typing import Optional, Union

keywords = {
    "and": TokenType.AND,
    "class": TokenType.CLASS,
    "else": TokenType.ELSE,
    "false": TokenType.FALSE,
    "for": TokenType.FOR,
    "fun": TokenType.FUN,
    "if": TokenType.IF,
    "nil": TokenType.NIL,
    "or": TokenType.OR,
    "print": TokenType.PRINT,
    "return": TokenType.RETURN,
    "super": TokenType.SUPER,
    "this": TokenType.THIS,
    "true": TokenType.TRUE,
    "var": TokenType.VAR,
    "while": TokenType.WHILE,
    "break": TokenType.BREAK,
    "static": TokenType.STATIC
}




class Lexer:
    def __init__(self, context: Context) -> None:
        self.source = context.source
        self.tokens: list[Token] = []
        self.line = 1
        self.start = 0
        self.current = 0
        self.context = context
        
    def scan_tokens(self) -> None:
        while(not self.is_at_end()):
            self.start = self.current
            self.scan_token()

        self.tokens.append(Token(TokenType.EOF, "",Span(self.start, self.current, self.line)))
        return self.tokens

    def is_at_end(self) -> bool:
        return self.current >= len(self.source)

    def add_token(self, _type: TokenType, text: Optional[Union[str, float]] = None) -> None:        
        text = text if text is not None else self.source[self.start:self.current]
        self.tokens.append(Token(_type, text, Span(self.start, self.current, self.line)))

    def advance(self) -> str:
        self.current += 1
        return self.source[self.current - 1]

    def match(self, expected: str) -> bool:
        if self.is_at_end() or self.source[self.current] != expected:
            return False
        
        self.current += 1
        return True

    def peek(self) -> str:
        return '' if self.is_at_end() else self.source[self.current]

    def is_digit(self, c: str) -> bool:
        return c >= '0' and c <= '9'

    def string(self):
        while self.peek() != '"' and not self.is_at_end():
            if self.peek() == '\n':
                self.line += 1
            self.advance()

        if self.is_at_end():
            self.context.error(self.line, "Unterminated string")
            return

        self.advance()
        self.add_token(TokenType.STRING, self.source[self.start + 1:self.current - 1])


    def number(self):
        while self.is_digit(self.peek()):
            self.advance()

        if self.peek() == '.' and self.is_digit(self.peek_next()):
            self.advance()
            while self.is_digit(self.peek()):
                self.advance()

        self.add_token(TokenType.NUMBER, float(self.source[self.start:self.current]))

    def peek_next(self) -> str:
        if(self.current + 1 > len(self.source)): return '/0'
        return self.source[self.current + 1]

    def is_alpha(self, c: str) -> bool:
        return c == "_" or c in string.ascii_letters

    def is_alpha_numeric(self, c: str) -> bool:
        return self.is_alpha(c) or self.is_digit(c)

    def identifier(self):
        while (self.is_alpha_numeric(self.peek()) and not self.is_at_end()):
            self.advance()
            
        self.add_token(keywords.get(self.source[self.start:self.current], TokenType.IDENTIFIER))

    def scan_token(self) -> None:
        c: str = self.advance()

        match c:
            case '(': self.add_token(TokenType.LEFT_PAREN)
            case ')': self.add_token(TokenType.RIGHT_PAREN)
            case '{': self.add_token(TokenType.LEFT_BRACE)
            case '}': self.add_token(TokenType.RIGHT_BRACE)
            case ',': self.add_token(TokenType.COMMA)
            case '.': self.add_token(TokenType.DOT)
            case '-': self.add_token(TokenType.MINUS)
            case '+': self.add_token(TokenType.PLUS)
            case ';': self.add_token(TokenType.SEMICOLON)
            case '*': self.add_token(TokenType.STAR)
            case '!': self.add_token(TokenType.BANG_EQUAL if  self.match('=') else TokenType.BANG)
            case '=': self.add_token(TokenType.EQUAL_EQUAL if self.match('=') else TokenType.EQUAL)
            case '<': self.add_token(TokenType.LESS_EQUAL if self.match('=') else TokenType.LESS)
            case '>': self.add_token(TokenType.GREATER_EQUAL if self.match('=') else TokenType.GREATER)
            case '/':
                if self.match('/'):
                    while (self.peek() != '\n' and not self.is_at_end()):
                        self.advance()
                else:
                    self.add_token(TokenType.SLASH)

            case (' '|'\r'|'\t'): pass
            case '\n': self.line += 1

            case '"': self.string()
            case _:  
                if self.is_digit(c):
                    self.number()
                elif self.is_alpha(c):
                    self.identifier()
                else:
                    self.context.error_span(f"Unexpected character '{c}'", Span(self.start, self.current, self.line))
            

