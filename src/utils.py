from dataclasses import dataclass
from functools import wraps
from pprint import pprint


@dataclass(unsafe_hash=True)
class Span:
    start: int
    end: int
    line: int

@dataclass
class Context:
    source: str
    file_name: str = "<stdin>"
    has_error: bool = False
    
    def error(self, line: int, message: str) -> None:
        self.report(line, self.file_name, message)

    def report(self, line: int, where: str, message: str) -> None:
        print(f"Error {where}: {message}")
        self.has_error = True


    def find_line_bounds_from_span(self, span: Span) -> tuple[int, int]:
        # sourcery skip: move-assign-in-block, use-next
        start = 0
        end = len(self.source)

        for i in range(span.start, 0, - 1):
            if self.source[i] == '\n':
                start = i + 1
                break

        for i in range(span.end, len(self.source)):
            if self.source[i] == '\n':
                end = i
                break

        return start, end

    def error_span(self, message: str, span: Span) -> None:
        start, end = self.find_line_bounds_from_span(span)
        
        line = self.source[start: end]
        error_line = f"{' '*(span.start - start)}^{'~'*(span.end - span.start - 1)}^--- {message}\n"
        
        print(f"Error at {self.file_name}:{span.line}:{span.start - start + 1}")
        print("  ",line)
        print("  ",error_line)
        self.has_error = True
