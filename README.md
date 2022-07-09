# Nut programming language

## Introduction

Nut is a programming language is based on the book 
[crafting interpreters](https://craftinginterpreters.com/) by Robert Nystrom. My implementation is written in python but will be ported to zig after finishing the bytecode vm.

## Reqirements

No libraries are required but the interpreter only runs on python 3.9+.

### Usage

### python3

`python3 pynut/nut.py <file>`
eg
`python pynut/nut.py src/examples/test.nut `
    
### zig

- build the interpreter
`zig build`

- run
`./zig-out/bin/nut <file>`