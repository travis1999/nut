from typing import Any,Union
from utils import Context, Span
from nutvisitor import ExprVisitor, StmntVisitor
import nutast as at
from nuttoken import Token, TokenType
from contextlib import contextmanager, _GeneratorContextManager
from nutcallable import NutCallable, NutNativeCallable, NutFunction
import time
from nuterror import InterpreterError, NutBreak, NutReturn
from nutenvironment import Environment
from nutclass import NutClass, NutInstance

NutUnion = Union[float, str, None, NutCallable]

        
class Interpreter(StmntVisitor, ExprVisitor):
    def __init__(self, context: Context):
        self.context = context
        self.locals: dict[at.Expr, int] = {}

        self.globals = Environment()
        self.globals.define("clock", NutNativeCallable(0, time.time))
        self.globals.define("str", NutNativeCallable(1, str))

        self.environment = self.globals

    def visit_literal_expr(self, expr: at.Literal) -> NutUnion:
        return expr.value

    def visit_grouping_expr(self, expr: at.Grouping) -> None:
        return self.evaluate(expr.expression)

    def resolve(self, expr: at.Expr, depth: int) -> None:
        self.locals[expr] = depth

    def evaluate(self, expr: at.Expr) -> Any:
        return expr.accept(self)

    def visit_break_stmnt(self, stmnt: 'at.Break') -> Any:
        raise NutBreak(stmnt.span)

    def visit_get_expr(self, expr: 'at.Get') -> Any:
        obj = self.evaluate(expr.object)
        if isinstance(obj, NutInstance):
            return obj.get(expr.name.value, expr.name.span)
        raise self.error(expr.span, "Only instances have properties")

    def visit_set_expr(self, expr: 'at.Set') -> Any:
        obj = self.evaluate(expr.object)
        
        if not isinstance(obj, NutInstance):
            raise self.error(expr.span, "Only instances have fields")

        ev = self.evaluate(expr.value)
        obj.set(expr.name.value, ev)

        return ev
    
    def visit_unary_expr(self, expr: at.Unary) -> float:
        right = self.evaluate(expr.right)

        match expr.operator.type:
            case TokenType.MINUS:
                self.check_number_operator(expr.operator, right)
                return -right
            
            case TokenType.BANG:
                return not right
            
        raise self.error(expr.operator.span, f"Unknown operator {expr.operator.type}")

    def error(self, span: Span, message: str)  -> InterpreterError:
        self.context.error_span(message, span)
        return InterpreterError(message)

    def visit_logical_expr(self, expr: 'at.Logical') -> Any:
        match expr.operator.type:
            case TokenType.OR:
                return self.evaluate(expr.left) or self.evaluate(expr.right)
            case TokenType.AND:
                return self.evaluate(expr.left) and self.evaluate(expr.right)

    def visit_while_stmnt(self, stmnt: 'at.While') -> Any:
        try:
            while(bool(self.evaluate(stmnt.condition))):
                self.execute(stmnt.body)
        except NutBreak:
            return

    
    def visit_assign_expr(self, expr: 'at.Assign') -> Any:
        value = self.evaluate(expr.value)

        if expr in self.locals:
            self.environment.assign_at(self.locals[expr], expr.name.value, value)
        else:
            self.globals.assign(expr.name.value, value)

        return value
    

    def visit_expression_stmnt(self, stmnt: at.Expression) -> None:
        self.evaluate(stmnt.expression)

    def visit_call_expr(self, expr: 'at.Call') -> Any:
        calee = self.evaluate(expr.callee)
        args = [self.evaluate(arg) for arg in expr.arguments]

        if not isinstance(calee, NutCallable):
            raise self.error(expr.span, "Can only call functions and classes")
        
        if calee.arity != (y := len(args)):
            raise self.error(expr.span, f"expected {calee.arity} args got {y}")

        return calee.call(self, args, expr.span)

    def visit_print_stmnt(self, stmnt: at.Print) -> None:
        value = self.evaluate(stmnt.expression)
        print(value)

    def visit_this_expr(self, expr: 'at.This') -> Any:
        return self.environment.get(expr.this.value, expr.this.span)

    def visit_class_stmnt(self, stmnt: 'at.Class') -> Any:
        self.environment.define(stmnt.name.value, None)

        methods: dict[str, NutFunction] = {}
        static_methods: dict[str, NutFunction] = {}
        
        for method in stmnt.methods:
            func = NutFunction(method, self.environment, method.name.value == "init")
            methods[method.name.value] = func

        for method in stmnt.static_methods:
            func = NutFunction(method, self.environment)
            static_methods[method.name.value] = func
        
        _class = NutClass(stmnt.name.value, methods, static_methods)
        self.environment.set(stmnt.name.value, _class)
        
    def visit_function(self, stmnt: at.Function) -> None:
        func = NutFunction(stmnt, self.environment)

        # if not self.environment.is_variable_unique(stmnt.name.value):
        #     raise self.error(stmnt.span, f"name '{stmnt.name.value}' for the function is already defined")
        self.environment.define(stmnt.name.value, func)

    def visit_if_stmnt(self, stmnt: 'at.If') -> Any:
        if bool(self.evaluate(stmnt.condition)):
            self.execute(stmnt.then_branch)
        elif stmnt.else_branch is not None:
            self.execute(stmnt.else_branch)

    def visit_return_stmnt(self, stmnt: at.Return) -> NutUnion:
        raise NutReturn(self.evaluate(stmnt.value) if stmnt.value else None, stmnt.span)


    @contextmanager
    def new_environment(self, env: Environment) -> _GeneratorContextManager['Environment', None, None]:
        pre = self.environment
        try:
            self.environment = env
            yield env
        finally:
            self.environment = pre


    def execute_block(self, statements: list[at.Stmnt], environment: Environment) -> None:
        with self.new_environment(environment):
            for stmnt in statements:
                self.execute(stmnt)
            
    def visit_block_stmnt(self, stmnt: 'at.Block') -> Any:
        self.execute_block(stmnt.statements, Environment(self.environment))

    def execute(self, stmnt: at.Stmnt) -> None:
        stmnt.accept(self)
               
    def check_number_operator(self, op: Token, oprand: object) -> None:
        if isinstance(oprand, float): return
        raise self.error(op.span, f"expected Number got {type(oprand)}")

    def check_number_oprands(self, sp: Span, left: object, right: object) -> None:
        
        if not all(isinstance(x, (float, int)) for x in (left, right)):
            raise self.error(sp, f"Oprands must be numbers not {type(left)} and {type(right)}")

    def visit_var_stmnt(self, stmnt: at.Var) -> None:
        if not isinstance(stmnt.name.value, str):
            raise self.error(stmnt.name.span, "[Internal] Variable name must be a string")

        # if not self.environment.is_variable_unique(stmnt.name.value):
        #     raise self.error(stmnt.span, f"variable {stmnt.name.value} is already defined")

        value = None if stmnt.initializer is None else self.evaluate(stmnt.initializer)
        self.environment.define(stmnt.name.value, value)

    def visit_variable_expr(self, expr: at.Variable) -> NutUnion:
        distance = self.locals.get(expr, None)

        if distance is not None:
            return self.environment.get_at(distance, expr.name.value)
        return self.globals.get(expr.name.value, None)

    def interpret(self, statements: list[at.Stmnt]) -> None:
        try:
            for statement in statements:
                self.execute(statement)
        except InterpreterError as e:
            if e.span:
                self.context.error_span(e.error, e.span)
            else:
                print(e.error)
            quit()

        except NutBreak as e:
            self.context.error_span("break outside of loop", e.span)
            quit()


    def visit_binary_expr(self, expr: at.Binary) -> Any:
        left = self.evaluate(expr.left)
        right = self.evaluate(expr.right)

        t = TokenType

        if expr.operator.type in [t.MINUS, t.SLASH, 
                                  t.STAR, t.GREATER, t.LESS,
                                  t.LESS_EQUAL, t.GREATER_EQUAL]:
            self.check_number_oprands(expr.span, left, right)

        match expr.operator.type:
            case TokenType.PLUS:
                if isinstance(left, float) and isinstance(right, float):
                    return left + right
                elif isinstance(left, str) and isinstance(right, str):
                    return left + right
                else:
                    raise self.error(expr.span, f"Oprands must be of type number or string, not {type(left)} and {type(right)}")
                    
            case TokenType.MINUS:
                return left - right
            case TokenType.SLASH:
                return left / right
            case TokenType.STAR:
                return left * right
            case TokenType.GREATER:
                return left > right
            case TokenType.LESS:
                return left < right
            case TokenType.EQUAL_EQUAL:
                return left == right
            case TokenType.BANG_EQUAL:
                return left != right
            case TokenType.LESS_EQUAL:
                return left <= right
            case TokenType.GREATER_EQUAL:
                return left >= right
            case TokenType.AND:
                return left and right
            case TokenType.OR:
                return left or right
