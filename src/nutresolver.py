from nutvisitor import ExprVisitor, StmntVisitor
from utils import Context
from nutastinterpreter import Interpreter
import nutast as at
from nuttoken import Token
from typing import Any, Generator, Optional, Union
from enum import Enum


class FunctionType(Enum):
    NONE = 0
    FUNCTION = 1
    METHOD = 2
    INITIALIZER = 3
    STATIC = 4

class ClassType(Enum):
    NONE = 0
    CLASS = 1
    SUBCLASS = 2
    INTERFACE = 3


class Resolver(ExprVisitor, StmntVisitor):
    def __init__(self, interpreter: Interpreter):
        self.interpreter = interpreter
        self.scopes: list[dict[str, bool]] = []
        self.current_function: FunctionType = FunctionType.NONE
        self.current_class: ClassType = ClassType.NONE

    def visit_block_stmnt(self, stmnt: at.Block):
        self.begin_scope()
        self.resolve(stmnt.statements)
        self.end_scope()

    def visit_var_stmnt(self, stmnt: at.Var):
        self.declare(stmnt.name)

        if stmnt.initializer is not None:
            self.resolve(stmnt.initializer)

        self.define(stmnt.name)

    def visit_break_stmnt(self, stmnt: 'at.Break') -> Any:
        pass
    
    def declare(self, name: Token):
        if not self.scopes:
            return

        if name.value in self.scopes[-1]:
            self.interpreter.context.error_span(f"Variable {name.value} already declared in this scope.", name.span)

        self.scopes[-1][name.value] = False


    def define(self, name: Token):
        if not self.scopes:
            return
        self.scopes[-1][name.value] = True

    def visit_variable_expr(self, expr: at.Variable) -> Any:        
        if self.scopes and  expr.name.value in self.scopes[-1] and self.scopes[-1][expr.name.value] is False:
            self.interpreter.context.error_span("Cannot read local variable in its own initializer.", expr.name.span)

        self.resolve_local(expr, expr.name)

    def visit_get_expr(self, expr: 'at.Get') -> Any:
        self.resolve(expr.object)

    def visit_set_expr(self, expr: 'at.Set') -> Any:
        self.resolve(expr.value)
        self.resolve(expr.object)
        
    def resolve_local(self, expr: at.Expr, name: Token):
        for idx, scope in enumerate(self.scopes[::-1]):
            if name.value in scope:
                self.interpreter.resolve(expr, idx)
                return

    def visit_assign_expr(self, expr: 'at.Assign') -> Any:
        self.resolve(expr.value)
        self.resolve_local(expr, expr.name)

    def visit_function(self, stmnt: 'at.Function') -> Any:
        self.declare(stmnt.name)
        self.define(stmnt.name)
        self.resolve_function(stmnt, FunctionType.FUNCTION)

    def resolve_function(self, stmnt: 'at.Function', _type: FunctionType):

        exclosing_function = self.current_function
        self.current_function = _type
        self.begin_scope()

        for tok in stmnt.params:
            self.declare(tok)
            self.define(tok)

        self.resolve(stmnt.body)
        self.end_scope()
        self.current_function = exclosing_function


    def visit_expression_stmnt(self, stmnt: 'at.Expression') -> Any:
        self.resolve(stmnt.expression)

    def visit_if_stmnt(self, stmnt: 'at.If') -> Any:
        self.resolve(stmnt.condition)
        self.resolve(stmnt.then_branch)

        if stmnt.else_branch is not None:
            self.resolve(stmnt.else_branch)

    def visit_print_stmnt(self, stmnt: 'at.Print') -> Any:
        self.resolve(stmnt.expression)

    def visit_return_stmnt(self, stmnt: 'at.Return') -> Any:
        if self.current_function is FunctionType.NONE:
            self.interpreter.context.error_span("Cannot return from top-level code.", stmnt.keyword.span)
        
        if stmnt.value is not None:
            if self.current_function is FunctionType.INITIALIZER:
                self.interpreter.context.error_span("Cannot return a value from an initializer.", stmnt.span)
            self.resolve(stmnt.value)

    def visit_class_stmnt(self, stmnt: 'at.Class') -> Any:
        enclosing = self.current_class
        self.current_class = ClassType.CLASS
        
        self.declare(stmnt.name)
        self.define(stmnt.name)


        self.begin_scope()
        self.scopes[-1]["this"] = True

        for method in stmnt.methods:
            dec = FunctionType.METHOD
            if method.name.value == "init":
                dec = FunctionType.INITIALIZER
            self.resolve_function(method, dec)

        for method in stmnt.static_methods:
            self.resolve_function(method, FunctionType.STATIC)
            

        self.end_scope()
        self.current_class = enclosing

    def visit_this_expr(self, expr: 'at.This') -> Any:
        if self.current_class is ClassType.NONE:
            self.interpreter.context.error_span("Cannot use 'this' outside of a class.", expr.span)
        if self.current_function is FunctionType.STATIC:
            self.interpreter.context.error_span("Cannot use 'this' in a static method.", expr.span)
        self.resolve_local(expr, expr.this)
        
    def visit_while_stmnt(self, stmnt: 'at.While') -> Any:
        self.resolve(stmnt.condition)
        self.resolve(stmnt.body)

    def visit_binary_expr(self, expr: 'at.Binary') -> Any:
        self.resolve(expr.left)
        self.resolve(expr.right)

    def visit_call_expr(self, expr: 'at.Call') -> Any:
        self.resolve(expr.callee)

        for arg in expr.arguments:
            self.resolve(arg)

    def visit_grouping_expr(self, expr: 'at.Grouping') -> Any:
        self.resolve(expr.expression)

    def visit_literal_expr(self, expr: 'at.Literal') -> Any:
        pass

    def visit_logical_expr(self, expr: 'at.Logical') -> Any:
        self.resolve(expr.left)
        self.resolve(expr.right)

    def visit_unary_expr(self, expr: 'at.Unary') -> Any:
        self.resolve(expr.right)
        
    def resolve_statements(self, stmnts: list[at.Stmnt]):
        for s in stmnts:
            self.resolve(s)

    def resolve(self, _type: Union[at.Stmnt, at.Expr, list[at.Stmnt]]):
        if isinstance(_type, list):
            return self.resolve_statements(_type)
        elif isinstance(_type, (at.Expr, at.Stmnt)):
            return _type.accept(self)

        assert False, "Unreachable"


    def begin_scope(self):
        self.scopes.append({})

    def end_scope(self):
        self.scopes.pop()

