from typing import Optional, Any
from utils import Span


class InterpreterError(BaseException):
    def __init__(self, error: str, *args: object, span: Optional[Span] = None) -> None:
        super().__init__(*args)
        self.error = error
        self.span = span

class NutBreak(BaseException):
    def __init__(self, span: Span):
        self.span = span

class NutReturn(BaseException):
    def __init__(self, value: Any, span: Span):
        self.value = value
        self.span = span
        
class ParserError(Exception):
    pass
