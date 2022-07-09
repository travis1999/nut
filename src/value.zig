const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const ValueType = enum { Bool, Number };

pub const Value = struct {
    v_type: ValueType,
    value: union { boolean: bool, number: f64 },
    is_on_heap: bool = false,

    pub fn bool_init(value: bool) Value {
        return .{ .v_type = .Bool, .value = .{ .boolean = value } };
    }

    pub fn number_init(value: f64) Value {
        return .{ .v_type = .Bool, .value = .{ .number = value } };
    }

    pub fn number_new(allocator: Allocator, value: f64) !*Value {
        var val = try allocator.create(Value);
        val.is_on_heap = true;

        val.v_type = .Number;
        val.value = .{ .number = value };
        return val;
    }

    pub fn bool_new(allocator: Allocator, value: bool) !*Value {
        var val = try allocator.create(Value);
        val.is_on_heap = true;

        val.v_type = .Bool;
        val.value = .{ .number = value };
        return val;
    }

    pub fn deinit(self: *Value, allocator: Allocator) void {
        if (self.is_on_heap) allocator.destroy(self);
    }

    pub fn as(self: *Value, comptime _type: ValueType) switch (_type) {
        .Bool => bool,
        .Number => f64,
    } {
        return switch (_type) {
            .Bool => self.value.boolean,
            .Number => self.value.number,
        };
    }

    pub fn is(self: *Value, _type: ValueType) bool {
        return self.v_type == _type;
    }

    pub fn print_value(self: *Value) void {
        switch (self.v_type) {
            .Number => std.debug.print("{d}", .{self.value.number}),
            .Bool => std.debug.print("{}", .{self.value.boolean})
        }
    }
};

pub const ValueArray = ArrayList(*Value);

test "as" {
    var val = Value.number_init(12.3);
    std.debug.print("number is {}\n", .{val.as(.Number)});
}
