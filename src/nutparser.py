from nuttoken import TokenType, Token
import nutast as at
from utils import Context, Span
from typing import Union
from nuterror import ParserError




class Parser:
    def __init__(self, tokens: list[Token], context: Context) -> None:
        self.tokens = tokens
        self.current = 0

        self.context = context


    def parse(self) -> list[at.Stmnt]:
        statements: list[at.Stmnt] = []

        while(not self.is_at_end()):
            statements.append(self.declaration())
            
        return statements


    def declaration(self) -> at.Stmnt:
        try:
            if self.match(TokenType.CLASS):
                return self.class_declaration()
            if self.match(TokenType.FUN):
                return self.function("function")
            if self.match(TokenType.VAR):
                return self.var_declaration()
            return self.statement()
        
        except ParserError:
            self.synchronize()



    def class_declaration(self) -> at.Stmnt:
        name = self.consume(TokenType.IDENTIFIER, "Expected class name")
        self.consume(TokenType.LEFT_BRACE, "Expected '{' after class name")
        
        methods = []
        static_methods = []



        while not self.check(TokenType.RIGHT_BRACE) and not self.is_at_end():
            if self.match(TokenType.STATIC):
                static_methods.append(self.function("static"))
            else:
                methods.append(self.function("method"))
                
        self.consume(TokenType.RIGHT_BRACE, "Expected '}' after class body")

        return at.Class(name.span, name, methods, static_methods)

    def function(self, kind: str) -> at.Function:
        name: Token = self.consume(TokenType.IDENTIFIER, f"Expect {kind} name.")
        self.consume(TokenType.LEFT_PAREN, f"Expect '(' after {kind} name")
        params = []

        if not self.check(TokenType.RIGHT_PAREN):
            while True:
                if len(params) >= 255:
                    raise self.error("Can't have more than 255 parameters")

                params.append(self.consume(TokenType.IDENTIFIER, "Expected parameter name"))

                if not self.match(TokenType.COMMA):
                    break

        self.consume(TokenType.RIGHT_PAREN, "Expected ')' after parameters")
        self.consume(TokenType.LEFT_BRACE, f"Expect '{{' before {kind} body")
        body = self.block()

        return at.Function(name.span, name, params, body)


    def var_declaration(self) -> at.Stmnt:
        name = self.consume(TokenType.IDENTIFIER, "Expected variable name")

        initializer = self.expression() if self.match(TokenType.EQUAL) else None

        self.consume(TokenType.SEMICOLON, "Expected ';' after variable declaration")

        return at.Var(name.span, name, initializer)

    def block(self) -> list[at.Stmnt]:
        statements = []

        while not self.check(TokenType.RIGHT_BRACE):
            statements.append(self.declaration())

        self.consume(TokenType.RIGHT_BRACE, "Expected '}' after block.")
        return statements
    
    def statement(self) -> at.Stmnt:
        if self.match(TokenType.FOR):
            return self.for_statement()
        if self.match(TokenType.IF):
            return self.if_statement()
        if self.match(TokenType.PRINT):
            return self.print_statement()
        if self.match(TokenType.RETURN):
            return self.return_statement()
        if self.match(TokenType.WHILE):
            return self.while_statement()
        if self.match(TokenType.BREAK):
            self.consume(TokenType.SEMICOLON, "Expected ';' after 'break'")
            return at.Break(self.previous().span)
        if self.match(TokenType.LEFT_BRACE):
            return at.Block(self.previous().span, self.block())
        
        return self.expression_statement()

    def return_statement(self) -> at.Return:
        keyword = self.previous()
        value = None if self.check(TokenType.SEMICOLON) else self.expression()
        self.consume(TokenType.SEMICOLON, "Expected ';' after return value")
        span = keyword.span
        if value:
            span.end = value.span.end

        return at.Return(span, keyword, value)


    def for_statement(self) -> at.Stmnt:
        self.consume(TokenType.LEFT_PAREN, "Expected '(' after 'for'")

        if self.match(TokenType.SEMICOLON):
            initializer = None
        elif self.match(TokenType.VAR):
            initializer = self.var_declaration()
        else:
            initializer = self.expression_statement()

        condition = None if self.check(TokenType.SEMICOLON) else self.expression()
        self.consume(TokenType.SEMICOLON, "Expected ';' after loop condition")

        increment = None if self.check(TokenType.RIGHT_PAREN) else self.expression()
        self.consume(TokenType.RIGHT_PAREN, "Expect ')' after clauses")

        body = self.statement()

        if increment is not None:
            sp = increment.span
            body = at.Block(sp, [body, at.Expression(sp, increment)])

        if condition is None:
            condition = at.Literal(None, True)

        body = at.While(None, condition, body)

        if initializer is not None:
            body = at.Block(None, [initializer, body])

        return body
    

    def while_statement(self) -> at.Stmnt:
        self.consume(TokenType.LEFT_PAREN, "Expected '(' after 'while'")
        condition = self.expression()
        self.consume(TokenType.RIGHT_PAREN, "Expected ')' after condition")
        body = self.statement()

        return at.While(self.span_from(condition, body), condition, body)

    def if_statement(self):
        self.consume(TokenType.LEFT_PAREN, "Expected '(' after 'if'")
        condition = self.expression()
        self.consume(TokenType.RIGHT_PAREN, "Expected ')' after condition")

        then_branch = self.statement()
        else_branch = self.statement() if self.match(TokenType.ELSE) else None
        return at.If(self.span_from(condition, else_branch or condition), condition, then_branch, else_branch)
        
    def print_statement(self) -> at.Stmnt:
        value = self.expression()
        self.consume(TokenType.SEMICOLON, "Expected ';' after value")
        return at.Print(value.span, value)

    def expression_statement(self) -> at.Stmnt:
        expr = self.expression()
        self.consume(TokenType.SEMICOLON, "Expected ';' after expression")
        return at.Expression(expr.span, expr)

    def Expr(self) -> at.Expr:
        return self.equality()

    def span_from(self, first: Union[at.Node, Token], last: Union[at.Node, Token]) -> Span:
        return Span(first.span.start, last.span.end, first.span.line)

    def match(self, *token_types: TokenType) -> bool:
        for tt in token_types:
            if self.check(tt):
                self.advance()
                return True
        return False

    def check(self, t_type: TokenType) -> bool:
        return False if self.is_at_end() else self.peek().type == t_type

    def advance(self) -> Token:
        if (not self.is_at_end()): self.current += 1
        return self.previous()

    def is_at_end(self) -> bool:
        return self.peek().type == TokenType.EOF

    def peek(self) -> Token:
        return self.tokens[self.current]

    def previous(self) -> Token:
        return self.tokens[self.current - 1]

    def expression(self) -> at.Expr:
        return self.assignment()

    def _or(self) -> at.Expr:
        expr = self._and()

        while (self.match(TokenType.OR)):
            operator: Token = self.previous()
            right = self._and()
            expr = at.Logical(self.span_from(expr, right), expr, operator, right)

        return expr

    def _and(self) -> at.Expr:
        expr = self.equality()

        while self.match(TokenType.AND):
            operator: Token = self.previous()
            right = self.equality()
            expr = at.Logical(self.span_from(expr, right), expr, operator, right)

        return expr

    def assignment(self) -> at.Expr:
        expr =  self._or()

        if (self.match(TokenType.EQUAL)):
            equals = self.previous()
            value = self.assignment()

            if (isinstance(expr, at.Variable)):
                t_name = expr.name
                return at.Assign(expr.span, t_name, value)
            elif (isinstance(expr, at.Get)):
                return at.Set(expr.span, expr.object, expr.name, value)

            raise self.error("Invalid assignment target")
        return expr

    def equality(self) -> at.Expr:
        expr = self.comparison()

        while(self.match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL)):
            operator: Token = self.previous()
            right: at.Expr = self.comparison()
            expr = at.Binary(self.span_from(expr, right), expr, operator, right)

        return expr

    def comparison(self) -> at.Expr:
        expr: at.Expr = self.term()

        while (self.match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL)):
            operator: Token = self.previous()
            right = self.term()
            expr = at.Binary(self.span_from(expr, right), expr, operator, right)

        return expr

    def term(self) -> at.Expr:
        expr = self.factor()
        
        while (self.match(TokenType.MINUS, TokenType.PLUS)):
            op = self.previous()
            right = self.factor()
            expr = at.Binary(self.span_from(expr, right), expr, op, right)

        return expr

    def factor(self) -> at.Expr:
        expr = self.unary()

        while (self.match(TokenType.SLASH, TokenType.STAR)):
            op = self.previous()
            right = self.factor()
            expr = at.Binary(self.span_from(expr, right), expr, op, right)

        return expr

    def unary(self) -> at.Expr:
        if (self.match(TokenType.BANG, TokenType.MINUS)):
            operator = self.previous()
            right = self.unary()
            return at.Unary(self.span_from(operator, right), operator, right)

        return self.call()

    def call(self) -> at.Expr:
        expr = self.primary()

        while (True):
            if self.match(TokenType.LEFT_PAREN):
                expr = self.finish_call(expr)
            elif self.match(TokenType.DOT):
                name = self.consume(TokenType.IDENTIFIER, "Expected property name after '.'")
                expr = at.Get(self.span_from(expr, name), expr, name)
            else:
                break
        return expr

    def finish_call(self, callee: at.Expr) -> at.Expr:
        #TODO: reimplement this function
        arguments = []

        if not self.match(TokenType.RIGHT_PAREN):
            arguments.append(self.expression())
            
            while self.match(TokenType.COMMA):
                if len(arguments) >= 255:
                    raise self.error("Cannot have more than 255 arguments")
                 
                arguments.append(self.expression())
                

        else:
            paren = self.previous()
            return at.Call(self.span_from(callee, paren), callee, arguments)
  

        paren = self.consume(TokenType.RIGHT_PAREN, "expected ')' after expression")

        return at.Call(self.span_from(callee, paren), callee, arguments)

        

    def primary(self) -> at.Expr:
        if self.match(TokenType.IDENTIFIER):
            return at.Variable(self.previous().span, self.previous())
                
        if self.match(TokenType.FALSE):
            return at.Literal(self.previous().span, False)

        if self.match(TokenType.TRUE):
            return at.Literal(self.previous().span, True)
        
        if self.match(TokenType.NIL): 
            return at.Literal(self.previous().span, None)

        if self.match(TokenType.NUMBER, TokenType.STRING):
            return at.Literal(self.previous().span, self.previous().value)

        if self.match(TokenType.THIS):
            return at.This(self.previous().span, self.previous())

        if self.match(TokenType.LEFT_PAREN):
            expr = self.expression()
            self.consume(TokenType.RIGHT_PAREN, "Expected ')' after expression")
            return at.Grouping(expr.span, expr)

        raise self.error("Expected expression")

    def consume(self, type: TokenType, message: str):
        if self.check(type): return self.advance()

        raise self.error(message)

    def error(self, message: str):
        self.context.error_span(f"syntax error: {message}", self.previous().span)
        return ParserError()


    def synchronize(self) -> None:
        """sync the parser to a usable state"""
        self.advance()

        while (not self.is_at_end()):
            
            if self.peek().type in  (TokenType.CLASS, TokenType.FUN, TokenType.VAR, TokenType.FOR, TokenType.IF, TokenType.WHILE, TokenType.PRINT, TokenType.RETURN, TokenType.STATIC):
                return
            
            self.advance()
