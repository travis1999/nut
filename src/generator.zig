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

    pub fn write_opcode(self: *Generator, opcode: chunk.OpCode, line: usize) !void {
        try self.curr_chunk.write_u8(@enumToInt(opcode));
        if (self.mode == Mode.DEBUG) try self.curr_chunk.write_u32(@intCast(u32, line));
    }

    fn write_oprand_u8(self: *Generator, byte: u8) !void {
        try self.curr_chunk.write_u8(byte);
    }

    fn write_oprand_u16(self: *Generator, value: u16) !void {
        try self.curr_chunk.write_16(value);
    }

    fn write_oprand_u32(self: *Generator, value: u32) !void {
        try self.curr_chunk.write_u32(value);
    }

    pub fn emit_return(self: *Generator, line: usize) !void {
        try self.write_opcode(chunk.OpCode.RETURN, line);
    }

    pub fn emit_constant(self: *Generator, value: *Value, line: usize) !void {
        var size = try self.make_constant(value);

        if (size < std.math.maxInt(u8)) {
            try self.write_opcode(chunk.OpCode.LOAD_CONST, line);
            try self.write_oprand_u8(@intCast(u8, size));
        } else {
            try self.write_opcode(chunk.OpCode.LOAD_CONST_LONG, line);
            try self.write_oprand_u32(@intCast(u32, size));
        }
    }

    fn make_constant(self: *Generator, value: *Value) !usize {
        var size = try self.curr_chunk.add_constant(value);
        return size;
    }
};
