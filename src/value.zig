const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const ValueType = enum { Bool, Number, Nil, String };

pub const NutString = struct {
    src: []u8,

    pub fn new(alloc: Allocator, str: []u8) !*NutString {
        var new_nut_str = try alloc.create(NutString);
        errdefer new_nut_str.deinit(alloc);

        new_nut_str.src = try NutString.clone_str(alloc, str);
        return new_nut_str;
    }

    pub fn concat(alloc: Allocator, str1: []u8, str2: []u8) ![]u8{
        var new_str = try alloc.alloc(u8, str1.len + str2.len);
        errdefer alloc.free(new_str);

        std.mem.copy(u8, new_str, str1);
        std.mem.copy(u8, new_str[str1.len..], str2);

        return new_str;
    }

    pub fn is_equal(self: *NutString, other: *NutString) bool {
        return std.mem.eql(u8, self.src, other.src);
    }

    pub fn clone_str(alloc: Allocator, str: []u8) ![]u8 {
        var new_str = try alloc.alloc(u8, str.len);
        errdefer alloc.free(new_str);

        std.mem.copy(u8, new_str, str);
        return new_str;
    }

    pub fn clone(self: *NutString, alloc: Allocator) !*NutString {
        var new_nut_str = try alloc.create(NutString);
        errdefer new_nut_str.deinit();

        new_nut_str.src = NutString.clone_str(self.src);
        return new_nut_str;
    }

    pub fn deinit(self: *NutString, alloc: Allocator) void {
        std.debug.print("deinit nut string\n", .{});
        alloc.free(self.src);
        alloc.destroy(self);
    }
};

pub const Value = struct {
    v_type: ValueType,
    value: union { boolean: bool, number: f64, string: *NutString },
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

    pub fn is_equal(self: *Value, other: *Value) bool {
        if (self.v_type != other.v_type) return false;

        switch (self.v_type) {
            .Bool => return self.as(.Bool) == other.as(.Bool),
            .Nil => return true,
            .Number => return self.as(.Number) == other.as(.Number),
            .String => return self.as(.String).is_equal(other.as(.String)),
        }
    }

    pub fn print_value(self: *Value) void {
        switch (self.v_type) {
            .Number => std.debug.print("{d}", .{self.value.number}),
            .Bool => std.debug.print("{}", .{self.value.boolean}),
            .Nil => std.debug.print("Nil", .{}),
            .String => std.debug.print("{s}", .{self.value.string}),
        }
    }
};

pub const ValueArray = ArrayList(*Value);

test "as" {
    var val = Value.number_init(12.3);
    std.debug.print("number is {}\n", .{val.as(.Number)});
}
