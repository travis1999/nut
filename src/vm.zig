const std = @import("std");
const chunk = @import("chunk.zig");
const value = @import("value.zig");

const String = value.NutString;
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
        print("\nat {d}\n", .{self.chunk.?.lines.items[self.ip]});
    }

    fn binary_op(comptime op: u8) fn (*Vm) anyerror!void {
        return struct {
            pub fn binary(this: *Vm) anyerror!void {
                if (op == '+') {
                    if (this.peek(0).is(.String) and this.peek(1).is(.String)) {
                        var a = this.pop().as(.String);
                        var b = this.pop().as(.String);
                        var concat = try a.concat(this.alloc, b);
                        
                        try this.push(try this.new_value(concat));
                        
                        //Fixme: allow strings to 'take' allocated memory
                        // this.alloc.free(concat);

                    } else if (this.peek(0).is(.Number) and this.peek(1).is(.Number)) {
                        try this.push(try this.new_value(this.pop().as(.Number) + this.pop().as(.Number)));
                    } else {
                        this.runtime_error("Operands must be two numbers or two strings.", .{});
                    }

                    return;
                }

                if (!this.peek(0).is(.Number) or !this.peek(1).is(.Number)) {
                    return this.runtime_error("Oprands must be numbers", .{});
                }

                var a = this.pop().as(.Number);
                var b = this.pop().as(.Number);

                switch (op) {
                    '-' => try this.push(try this.new_value(b - a)),
                    '*' => try this.push(try this.new_value(b * a)),
                    '/' => try this.push(try this.new_value(b / a)),
                    '>' => try this.push(try this.new_value(a > b)),
                    '<' => try this.push(try this.new_value(a < b)),

                    else => unreachable,
                }
            }
        }.binary;
    }

    pub fn new_value(self: *Vm, n_value: anytype) !*Value {
        var val = try Value.value_new(self.alloc, n_value);
        try self.allocated.append(val);
        return val;
    }

    pub fn is_false(_: *Vm, val: *Value) bool {
        return val.is(.Nil) or (val.is(.Bool) and !val.as(.Bool));
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
                    if (self.stack.items.len > 0) self.peek(0).print_value();
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
                .GREATER => Vm.binary_op('>')(self),
                .LESS => Vm.binary_op('<')(self),
                .NEGATE => {
                    if (!self.peek(0).is(.Number)) {
                        return self.runtime_error("Oprand must be a number", .{});
                    }
                    try self.push(try self.new_value(-self.pop().as(.Number)));
                },
                .NIL => try self.push(try self.new_value(null)),
                .TRUE => try self.push(try self.new_value(true)),
                .FALSE => try self.push(try self.new_value(false)),
                .NOT => try self.push(try self.new_value(self.is_false(self.pop()))),
                .EQUAL => try self.push(try self.new_value(self.pop().is_equal(self.pop()))),
            };
        }
    }
};
