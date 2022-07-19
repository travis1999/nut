const std = @import("std");
const vm = @import("vm.zig");
const chunk = @import("chunk.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const scanner = @import("scanner.zig");
const generator = @import("generator.zig");
const parser = @import("parser.zig");
const Mode = @import("common.zig").Mode;

const print = std.debug.print;


pub const CompilerError = error {
    ParsingError
};

pub const Compiler = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Compiler {
        return Compiler {.allocator=allocator};
    }

    pub fn deinit(self: *Compiler) void {
        _ = self;
    }


    pub fn emit_byte(self: *Compiler, byte: u8) void {
        _ = self;
        _ = byte;
    }

    pub fn compile(self: *Compiler, source: [] u8) !?*chunk.Chunk {
        _ = self;

        var scan = scanner.Scanner.init(source);
        var cnk = try chunk.Chunk.new(self.allocator);
        errdefer cnk.deinit();
        
        var gen = generator.Generator.init(cnk, Mode.DEBUG);
        var par = parser.Parser.init(self.allocator, &scan, &gen);

        par.parse();

        if (par.haserror) {
            cnk.deinit();
            return null;
        }

        cnk.disassemble_chunk("debug");
        return cnk;
    }
};