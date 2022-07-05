from nutcallable import NutCallable
from utils import Span
from typing import Any
from nuterror import InterpreterError


class NutInstance:
    def __init__(self, _class: 'NutClass') -> None:
        self._class = _class
        self.fields: dict[str, Any] = {}

    def __str__(self) -> str:
        return f"{self._class.name}({', '.join(f'{k}={v}' for k, v in self.fields.items())})"

    def get(self, name: str, span=None) -> Any:
        if name in self.fields:
            return self.fields[name]
        
        if (meth := self._class.find_method(name)) is not None:
            return meth.bind(self)

        raise InterpreterError(f"Undefined property '{name}'.", span=span)
        
    def set(self, name: str, value: Any) -> None:
        self.fields[name] = value

    
class NutClass(NutInstance, NutCallable):
    def __init__(self, name: str, methods: dict[str, NutCallable], static_methods: dict[str, NutCallable]) -> None:
        super().__init__(self)
        self.name = name
        self.methods: dict[str, NutCallable] = methods
        self.fields = static_methods

    @property
    def arity(self):
        return init.arity if ((init := self.find_method("init"))) else 0

    def find_method(self, meth: str) -> NutCallable:
        if meth in self.methods:
            return self.methods[meth]

    def call(self, interpreter, arguments, span: Span):
        instance = NutInstance(self)

        
        if (meth := self.find_method("init")) is not None:
            return meth.bind(instance).call(interpreter, arguments, span)  
        else:
            return instance

        

    def __str__(self) -> str:
        return f"<class {self.name}>"

    