from dataclasses import dataclass
from nutlexer import Token
from utils import Span
from nutvisitor import ExprVisitor, StmntVisitor
from abc import ABC, abstractmethod
from typing import Any, Optional, Union


@dataclass(unsafe_hash=True)
class Node:
    span: Span
    

@dataclass # type: ignore
class Expr(ABC, Node):
    
    @abstractmethod
    def accept(self, visitor: ExprVisitor) -> Any:
        ...

@dataclass(unsafe_hash=True)
class Binary(Expr):
    left: Expr
    operator: Token
    right: Expr

    def __str__(self) -> str:
        return f"({self.left} {self.operator.value} {self.right})"

    def accept(self, visitor: ExprVisitor) -> Any:
        return visitor.visit_binary_expr(self)

    
    
@dataclass
class Grouping(Expr):
    expression: Expr

    def __str__(self) -> str:
        return f"({self.expression})"

    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_grouping_expr(self)

@dataclass(unsafe_hash=True)
class Literal(Expr):
    value: Union[float, str, Any]

    def __str__(self) -> str:
        return str(self.value)

    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_literal_expr(self)

@dataclass(unsafe_hash=True)
class Assign(Expr):
    name: Token
    value: Expr

    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_assign_expr(self)

    def __str__(self) -> str:
        return f"{self.name.value} = {self.value}"

@dataclass
class Get(Expr):
    object: Expr
    name: Token

    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_get_expr(self)

    def __str__(self) -> str:
        return f"{self.object}.{self.name.value}"

@dataclass
class Set(Expr):
    object: Expr
    name: Token
    value: Expr

    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_set_expr(self)

    def __str__(self) -> str:
        return f"{self.object}.{self.name.value} = {self.value}"

@dataclass(unsafe_hash=True)
class This(Expr):
    this: Token
    
    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_this_expr(self)

    def __str__(self) -> str:
        return "this"

@dataclass
class Unary(Expr):
    operator: Token
    right: Expr

    def accept(self, visitor: 'ExprVisitor') -> Any:
        return visitor.visit_unary_expr(self)

    def __str__(self) -> str:
        return f"{self.operator.value}{self.right}"


@dataclass(unsafe_hash=True)
class Variable(Expr):
    name: Token

    def accept(self, visitor: ExprVisitor) -> Any:
        return visitor.visit_variable_expr(self)

    def __str__(self) -> str:
        return self.name.value




@dataclass
class Logical(Expr):
    left: Expr
    operator: Token
    right: Expr

    def accept(self, visitor: ExprVisitor) -> Any:
        return visitor.visit_logical_expr(self)

    def __str__(self) -> str:
        return f"({self.left} {self.operator} {self.right})"

@dataclass
class Call(Expr):
    callee: Expr
    arguments: list[Expr]

    def accept(self, visitor: ExprVisitor) -> Any:
        return visitor.visit_call_expr(self)

    def __str__(self) -> str:
        return f"{self.callee}({', '.join(str(x) for x in self.arguments)})"

@dataclass # type: ignore
class Stmnt(ABC, Node):
    
    @abstractmethod
    def accept(self, visitor: StmntVisitor) -> Any:
        ...


@dataclass
class Var(Stmnt):
    name: Token
    initializer: Optional[Expr] = None

    def accept(self, visitor: 'StmntVisitor') -> Any:
        return visitor.visit_var_stmnt(self)

    def __str__(self) -> str:
        return f"var {self.name.value} = {self.initializer}"

@dataclass
class Function(Stmnt):
    name: Token
    params: list[Token]
    body: list[Stmnt]

    def accept(self, visitor: 'StmntVisitor') -> Any:
        return visitor.visit_function(self)

    def __str__(self) -> str:
        nl = "\n"
        return f"fn ({', '.join(p.value for p in self.params)})\n  {f'{nl}'.join(str(x) for x in self.body)}"

@dataclass
class Expression(Stmnt):
    expression: Expr

    def accept(self, visitor: 'StmntVisitor') -> Any:
        return visitor.visit_expression_stmnt(self)

    def __str__(self) -> str:
        return str(self.expression)


@dataclass
class Return(Stmnt):
    keyword: Token
    value: Expr

    def accept(self, visitor: 'StmntVisitor') -> Any:
        return visitor.visit_return_stmnt(self)

    def __str__(self) -> str:
        return f"return {self.value}"

@dataclass
class Print(Stmnt):
    expression: Expr

    def accept(self, visitor: 'StmntVisitor') -> Any:
        return visitor.visit_print_stmnt(self)

    def __str__(self) -> str:
        return f"print {self.expression}"

@dataclass
class Block(Stmnt):
    statements: list[Stmnt]

    def accept(self, visitor: StmntVisitor) -> Any:
        return visitor.visit_block_stmnt(self)

    def __str__(self) -> str:
        st = "  {\n"
        for s in self.statements:
            st += f"    {s}\n"
        st += "  }\n"

        return st


@dataclass
class If(Stmnt):
    condition: Expr
    then_branch: Stmnt
    else_branch: Optional[Stmnt] = None

    def accept(self, visitor: StmntVisitor) -> Any:
        return visitor.visit_if_stmnt(self)

    def __str__(self) -> str:
        return f"if {self.condition} : {self.then_branch} ? {self.else_branch}"

@dataclass
class Break(Stmnt):
    def accept(self, visitor: StmntVisitor) -> Any:
        return visitor.visit_break_stmnt(self)

    def __str__(self) -> str:
        return "break"

@dataclass
class While(Stmnt):
    condition: Expr
    body: Stmnt

    def accept(self, visitor: StmntVisitor) -> Any:
        return visitor.visit_while_stmnt(self)

    def __str__(self) -> str:
        return f"while {self.condition}\n{self.body}"

@dataclass
class Class(Stmnt):
    name: Token
    methods: list[Function]
    static_methods: list[Function]

    def accept(self, visitor: StmntVisitor) -> Any:
        return visitor.visit_class_stmnt(self)

    def __str__(self) -> str:
        nl = "\n"
        return f"class {self.name.value}\n{f'{nl}'.join(str(x) for x in self.methods)}"