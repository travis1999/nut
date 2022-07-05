from typing import Optional, Union, Any
from nuterror import InterpreterError
from utils import Span


NutUnion = Any


class Environment:
    def __init__(self, enclosing: Optional["Environment"] = None) -> None:
        self.enlosing_environment = enclosing
        self.values: dict[str, Union[float, str, None]] = {}

    def get(self, name: str, span: Optional[Span] = None) -> NutUnion:
        if name in self.values:
            return self.values[name]
        elif self.enlosing_environment is not None:
            return self.enlosing_environment.get(name)

        raise InterpreterError(f"Undefined variable '{name}'", span=span)

    def is_variable_unique(self, name: str) -> bool:
        if name in self.values:
            return False
        elif self.enlosing_environment is not None:
            return self.enlosing_environment.is_variable_unique(name)
        return True
        
    def set(self, name: str, value: NutUnion) -> None:
        if name in self.values:
            self.values[name] = value
            return
        if self.enlosing_environment is not None:
            self.enlosing_environment.set(name, value)
            return
        raise InterpreterError(f"Undefined variable '{name}'")

    def get_at(self, distance: int, name: str) -> NutUnion:
        return self.ancestor(distance).get(name)

    def assign_at(self, distance: int, name: str, value: NutUnion) -> None:
        self.ancestor(distance).set(name, value)

    def ancestor(self, distance: int) -> "Environment":
        environment = self
        
        for _ in range(distance):
            environment = environment.enlosing_environment

        return environment

    def define(self, name: str, value: Union[float, str, None]) -> None:
        self.values[name] = value

