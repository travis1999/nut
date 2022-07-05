import argparse
import os
from typing import Optional
from utils import Context
from nutlexer import Lexer
from nutparser import Parser
from nutastinterpreter import Interpreter
from nutresolver import Resolver


class Nut:
    def __init__(self) -> None:
        self.has_error = False
        self.source: Optional[list[str]] = None

    def run_file(self, filename: str) -> None:
        if not os.path.isfile(filename):
            print(f"{filename} does not exist.")
            return
        
        with open(filename) as f:
            lines = f.read()
            context = Context(lines, filename)
            
        tokens = Lexer(context).scan_tokens()
        statements = Parser(tokens, context).parse()
        if context.has_error: return

        intp = Interpreter(context)
        Resolver(intp).resolve(statements)
        if context.has_error: return
        
        intp.interpret(statements)
        

    def run_prompt(self) -> None:
        intp = Interpreter(None)
        
        while True:
            try:
                print(">>> ", end="")
                line = input()
                if line == "exit":
                    break
                context = Context(line)
                intp.context = context

                tokens = Lexer(context).scan_tokens()
                statements = Parser(tokens, context).parse()
                if context.has_error: continue

                Resolver(intp).resolve(statements)
                if context.has_error: continue
                
                intp.interpret(statements)
                
            except (KeyboardInterrupt, EOFError):
                break


    def main(self) -> None:
        parser = argparse.ArgumentParser()
        parser.add_argument("file", nargs="?", default=None)
        parsed = parser.parse_args()

        if parsed.file is None:
            self.run_prompt()
        else:
            self.run_file(parsed.file)


if __name__ == "__main__":
    Nut().main()
