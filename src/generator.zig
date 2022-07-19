const std = @import("std");
const vm = @import("vm.zig");
const chunk = @import("chunk.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const scanner = @import("scanner.zig");
const TokenType = scanner.TokenType;
const print = std.debug.print;
const Mode = @import("common.zig").Mode;
const Value = @import("value.zig").Value;

pub const Generator = struct {
    curr_chunk: *chunk.Chunk,
    mode: Mode,

    pub fn init(chunk_: *chunk.Chunk, mode: Mode) Generator {
        return Generator{ .curr_chunk = chunk_, .mode = mode };
    }

    pub fn write_opcode(self: *Generator, opcode: chunk.OpCode, line: usize) void {
        self.curr_chunk.write_chunk(opcode, line);
    }

    fn write_oprand_u8(self: *Generator, byte: u8, line: usize) void {
        self.curr_chunk.write_u8(byte, line);
    }

    fn write_oprand_u16(self: *Generator, value: u16, line: usize) void {
        self.curr_chunk.write_16(value, line);
    }

    fn write_oprand_u32(self: *Generator, value: u32, line: usize) void {
        self.curr_chunk.write_u32(value, line);
    }

    pub fn emit_return(self: *Generator, line: usize) void {
        self.write_opcode(chunk.OpCode.RETURN, line);
    }

    pub fn emit_constant(self: *Generator, value: *Value, line: usize) usize {
        var size = self.make_constant(value);

        if (size < std.math.maxInt(u8)) {
            self.write_opcode(chunk.OpCode.LOAD_CONST, line);
            self.write_oprand_u8(@intCast(u8, size), line);
        } else {
            self.write_opcode(chunk.OpCode.LOAD_CONST_LONG, line);
            self.write_oprand_u32(@intCast(u32, size), line);
        }
        return size;
    }

    pub fn define_variable(self: *Generator, global: usize, line: usize) void {
        if (global < 254) {
            self.write_opcode(.DEFINE_GLOBAL, line);
            self.write_oprand_u8(@intCast(u8, global), line);
        }else {
            self.write_opcode(.DEFINE_GLOBAL_LONG, line);
            self.write_oprand_u32(@intCast(u32, global), line);
        }
    }

    fn make_constant(self: *Generator, value: *Value) usize {
        var size = self.curr_chunk.add_constant(value);
        return size;
    }
};
