const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;
const print = std.debug.print;
const value = @import("value.zig");
const Value = value.Value;
const ValueArray = value.ValueArray;


// zig fmt: off
pub const OpCode = enum { 
    RETURN,
    LOAD_CONST,
    LOAD_CONST_LONG,
    ADD,
    SUB,
    MULTIPLY,
    DIVIDE,
    NEGATE,
    NIL,
    TRUE,
    FALSE,
    NOT,
    EQUAL,
    GREATER,
    LESS,
    PRINT,
    POP,
    DEFINE_GLOBAL,
    DEFINE_GLOBAL_LONG
};

pub const Chunk = struct {
    code: ArrayList(u8),
    allocator: Allocator,
    constants: ValueArray,
    pre_line: usize = 0,
    lines: ArrayList(usize),

    pub fn new(alloc: Allocator) !*Chunk {
        var chunk = try alloc.create(Chunk);
        chunk.allocator = alloc;
        chunk.code = ArrayList(u8).init(alloc);
        chunk.constants = ValueArray.init(alloc);
        chunk.lines = ArrayList(usize).init(alloc);

        return chunk;
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();

        for (self.constants.items) |constant| {
            constant.deinit(self.allocator);
        }

        self.lines.deinit();
        self.constants.deinit();
        self.allocator.destroy(self);
    }

    pub fn add_line(self: *Chunk, line: usize) void {
        self.lines.append(line) catch {
            @panic("Error writing chunk, out of memory");
        };
    }

    pub fn write_chunk(self: *Chunk, op: OpCode, line: usize) void {
        self.write_u8(@enumToInt(op), line);
    }

    pub fn write_u8(self: *Chunk, _value: u8, line: usize) void {
        self.code.append(_value) catch {
            @panic("Error writing chunk, out of memory");
        };

        self.add_line(line);
    }

    pub fn write_u16(self: *Chunk, _value: u16, line: usize) void {
        //split into two u8s

        self.write_u8(_value >> 8, line);
        self.write_u8(_value & 0xFF, line);
    }

    pub fn write_u32(self: *Chunk, _value: u32, line: usize) void {
        var bytes = [4]u32{ _value >> 24, _value >> 16, _value >> 8, _value & 0xFF };

        for (bytes) |b| {
            self.write_u8(@intCast(u8, b), line);
        }
    }

    pub fn code_at(self: *Chunk, index: usize) u8 {
        return self.code.items[index];
    }

    pub fn read_u8(self: *Chunk, index: usize) u8 {
        return self.code.items[index];
    }
    pub fn read_u16(self: *Chunk, _index: u32) u16 {
        //read two u8s
        return @as(u16, self.code_at(_index)) << 8 | @as(u16, self.code_at(_index + 1));
    }

    pub fn read_u32(self: *Chunk, _index: usize) u32 {
        //read four into a u32
        return @as(u32, self.code_at(_index)) << 24 | @as(u32, self.code_at(_index + 1)) << 16 | @as(u32, self.code_at(_index + 2)) << 8 | @as(u32, self.code_at(_index + 3));
    }

    pub fn disassemble_chunk(self: *Chunk, name: []const u8) void {
        print("\n=== {s} ===\n", .{name});

        var offset: usize = 0;

        while (offset < self.code.items.len) {
            offset = self.disasemble_ins(offset);
        }
    }

    pub fn disasemble_ins(self: *Chunk, offset: usize) usize {
        var of_tmp = offset;

        var op = @intToEnum(OpCode, self.read_u8(offset));
        of_tmp += 1;

        var line = self.lines.items[offset];

        //line(4)//op(1)//oprand(1)

        if (line == self.pre_line) {
            print("{d:0>4} {s:>6} {}", .{ offset, "|", op });
        } else {
            print("{d:0>4} {d:>6} {}", .{ offset, line, op });
            self.pre_line = line;
        }

        switch (op) {
            .LOAD_CONST => {
                var it = self.code.items[of_tmp];
                of_tmp += 1;
                print("{d:>6} '", .{it});
                self.constants.items[it].print_this();
                print("'", .{});
            },
            .LOAD_CONST_LONG => {
                var it = self.read_u32(of_tmp);
                of_tmp += 4;
                print("{d:>6} '", .{it});
                self.constants.items[it].print_this();
                print("'", .{});
            },

            else => {},
        }
        print("\n", .{});
        return of_tmp;
    }

    pub fn add_constant(self: *Chunk, val: *Value) usize {
        self.constants.append(val) catch {
            @panic("Error writing chunk, out of memory");
        };
        return self.constants.items.len - 1;
    }
};
