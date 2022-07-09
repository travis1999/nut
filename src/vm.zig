const std = @import("std");
const chunk = @import("chunk.zig");
const value = @import("value.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Chunk = chunk.Chunk;
const Opcode = chunk.OpCode;
const Value = value.Value;
const print = std.debug.print;

const trace = true;

pub const Vm = struct {
    chunk: ?*chunk.Chunk = null,
    ip: usize = 0,
    stack: ArrayList(*Value),
    alloc: Allocator,
    allocated: ArrayList(*Value),

    pub fn init(alloc: Allocator) !Vm {
        return Vm{ .alloc = alloc, .stack = ArrayList(*Value).init(alloc), .allocated = ArrayList(*Value).init(alloc) };
    }

    pub fn deinit(self: *Vm) void {
        // if (self.chunk) |ck| {
        //     ck.deinit();
        // }

        for (self.allocated.items) |allocated| {
            allocated.deinit(self.alloc);
        }

        self.allocated.deinit();
        self.stack.deinit();
    }

    pub fn interpret(self: *Vm, _chunk: *Chunk) !void {
        self.chunk = _chunk;
        self.ip = 0;
        return try self.run();
    }

    fn read_u8(self: *Vm) u8 {
        self.ip += 1;
        return self.chunk.?.read_u8(self.ip - 1);
    }

    fn read_u32(self: *Vm) u32 {
        var ck = self.chunk.?.read_u32(self.ip);
        self.ip += 4;
        return ck;
    }

    fn read_constant(self: *Vm) *Value {
        return self.chunk.?.constants.items[self.read_u8()];
    }

    fn read_constant_long(self: *Vm) *Value {
        return self.chunk.?.constants.items[self.read_u32()];
    }

    fn reset_stack(self: *Vm) void {
        self.stack.clearAndFree();
    }

    fn push(self: *Vm, val: *Value) !void {
        try self.stack.append(val);
    }

    fn pop(self: *Vm) *Value {
        return self.stack.pop();
    }

    fn peek(self: *Vm, dist: usize) *Value {
        return self.stack.items[self.stack.items.len - 1 - dist];
    }

    fn runtime_error(self: *Vm, comptime fmt: []const u8, args: anytype) void {
        print(fmt, args);
        print("at {d}\n", .{self.chunk.?.lines.items[self.ip]});
    }

    fn binary_op(comptime op: u8) fn (*Vm) anyerror!void {
        return struct {
            pub fn binary(this: *Vm) anyerror!void {
                if (!this.peek(0).is(.Number) or !this.peek(1).is(.Number)) {
                    return this.runtime_error("Oprands must be numbers", .{});
                }

                var a = this.pop().as(.Number);
                var b = this.pop().as(.Number);

                switch (op) {
                    '+' => try this.push(try Value.number_new(this.alloc, b + a)),
                    '-' => try this.push(try Value.number_new(this.alloc, b - a)),
                    '*' => try this.push(try Value.number_new(this.alloc, b * a)),
                    '/' => try this.push(try Value.number_new(this.alloc, b / a)),
                    else => unreachable,
                }

                try this.allocated.append(this.peek(0));
            }
        }.binary;
    }

    pub fn run(self: *Vm, cnk: *Chunk) !void {
        self.chunk = cnk;
        print("\n\n-----bytecode Trace-----\n\n", .{});
        while (true) {
            if (trace) {
                _ = try self.chunk.?.disasemble_ins(self.ip);
            }

            var ins = @intToEnum(Opcode, self.read_u8());

            try switch (ins) {
                .RETURN => {
                    self.peek(0).print_value();
                    return;
                },
                .LOAD_CONST => {
                    var constant = self.read_constant();
                    try self.push(constant);
                },
                .LOAD_CONST_LONG => {
                    var constant = self.read_constant_long();
                    try self.push(constant);
                },

                .ADD => Vm.binary_op('+')(self),
                .SUB => Vm.binary_op('-')(self),
                .MULTIPLY => Vm.binary_op('*')(self),
                .DIVIDE => Vm.binary_op('/')(self),
                .NEGATE => {
                    if (!self.peek(0).is(.Number)) {
                        return self.runtime_error("Oprand must be a number", .{});
                    }

                    try self.push(try Value.number_new(self.alloc, -self.pop().as(.Number)));
                    try self.allocated.append(self.peek(0));
                },
            };
        }
    }
};
