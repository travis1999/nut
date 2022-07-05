from abc import ABC, abstractmethod
from typing import Callable, Union
from nuterror import NutReturn, InterpreterError
from nutenvironment import Environment
from utils import Span


class NutCallable(ABC):
    def __init__(self, arity: int):
        self.arity = arity

    @abstractmethod
    def call(self, interpreter, arguments, span: Span):
        ...


class NutNativeCallable(NutCallable):
    def __init__(self, arity: int, _callable: Callable[[], Union[float, str, None]]):
        super().__init__(arity)
        self.callable = _callable

    def call(self, interpreter, arguments, span: Span):
        try:
            return self.callable(*arguments)
        except Exception as e:
            raise InterpreterError(str(e), span=span) from e


    def __str__(self) -> str:
        return f"<builtin function {self.callable.__name__}>"


class NutFunction(NutCallable):
    def __init__(self, function, closure: Environment, is_init=False):
        super().__init__(len(function.params))
        self.callable = function
        self.closure = closure
        self.is_init = is_init

    def call(self, interpreter, arguments: list, span: Span):
        env = Environment(self.closure)

        for idx, t in enumerate(self.callable.params):
            env.define(t.value, arguments[idx])
        try:
            interpreter.execute_block(self.callable.body, env)
        except NutReturn as e:
            return self.closure.get_at(0, "this") if self.is_init else e.value


        if self.is_init:
            return self.closure.get_at(0, "this")

        return "baba"

    def bind(self, instance: 'NutInstance') -> 'NutFunction':
        env = Environment(self.closure)
        env.define("this", instance)
        return NutFunction(self.callable, env, self.is_init)

    def __str__(self) -> str:
        return f"<function {self.callable.name.value}>"

from nutclass import NutInstance
