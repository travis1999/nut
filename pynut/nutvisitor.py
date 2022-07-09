from abc import ABC, abstractmethod
from typing import Any


class ExprVisitor(ABC):
    @abstractmethod
    def visit_binary_expr(self, expr: 'at.Binary') -> Any:
        ...
    
    @abstractmethod
    def visit_grouping_expr(self, expr: 'at.Grouping') -> Any:
        ...
    
    @abstractmethod
    def visit_literal_expr(self, expr: 'at.Literal') -> Any:
        ...
    
    @abstractmethod
    def visit_unary_expr(self, expr: 'at.Unary') -> Any:
        ...

    @abstractmethod
    def visit_variable_expr(self, expr: 'at.Variable') -> Any:
        ...

    @abstractmethod
    def visit_assign_expr(self, expr: 'at.Assign') -> Any:
        ...

    @abstractmethod
    def visit_logical_expr(self, expr: 'at.Logical') -> Any:
        ...

    @abstractmethod
    def visit_call_expr(self, expr: 'at.Call') -> Any:
        ...

    @abstractmethod
    def visit_get_expr(self, expr: 'at.Get') -> Any:
        ...

    @abstractmethod
    def visit_set_expr(self, expr: 'at.Set') -> Any:
        ...

    @abstractmethod
    def visit_this_expr(self, expr: 'at.This') -> Any:
        ...


class StmntVisitor(ABC):
    @abstractmethod
    def visit_expression_stmnt(self, stmnt: 'at.Expression') -> Any:
        ...
    
    @abstractmethod
    def visit_print_stmnt(self, stmnt: 'at.Print') -> Any:
        ...

    @abstractmethod
    def visit_var_stmnt(self, stmnt: 'at.Var') -> Any:
        ...

    @abstractmethod
    def visit_block_stmnt(self, stmnt: 'at.Block') -> Any:
        ...

    @abstractmethod
    def visit_if_stmnt(self, stmnt: 'at.If') -> Any:
        ...

    @abstractmethod
    def visit_while_stmnt(self, stmnt: 'at.While') -> Any:
        ...

    @abstractmethod
    def visit_break_stmnt(self, stmnt: 'at.Break') -> Any:
        ...

    @abstractmethod
    def visit_function(self, stmnt: 'at.Function') -> Any:
        ...

    @abstractmethod
    def visit_return_stmnt(self, stmnt: 'at.Return') -> Any:
        ...

    @abstractmethod
    def visit_class_stmnt(self, stmnt: 'at.Class') -> Any:
        ...

import nutast as at
