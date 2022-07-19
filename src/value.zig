const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoMap = std.AutoArrayHashMap;

pub const ValueType = enum { Bool, Number, Nil, String };

pub const NutString = struct {
    src: []u8,

    pub fn new(alloc: Allocator, str: []u8) *NutString {
        var new_nut_str = alloc.create(NutString) catch {
            @panic("Out Of memory");
        };

        new_nut_str.src = NutString.clone_str(alloc, str);
        return new_nut_str;
    }

    pub fn take(alloc: Allocator, str: []u8) *NutString {
        var new_nut_str = alloc.create(NutString) catch {
            @panic("Out Of memory");
        };

        new_nut_str.src = str;
        return new_nut_str;
    }

    pub fn concat_str(alloc: Allocator, str1: []u8, str2: []u8) []u8 {
        var new_str = alloc.alloc(u8, str1.len + str2.len) catch {
            @panic("Out Of memory");
        };

        std.mem.copy(u8, new_str, str1);
        std.mem.copy(u8, new_str[str1.len..], str2);

        return new_str;
    }

    pub fn concat(self: *NutString, alloc: Allocator, other: *NutString) *NutString {
        var new_nut_str = NutString.take(alloc, NutString.concat_str(alloc, self.src, other.src));
        errdefer new_nut_str.deinit(alloc);
        return new_nut_str;
    }

    pub fn is_equal(self: *NutString, other: *NutString) bool {
        return std.mem.eql(u8, self.src, other.src);
    }

    pub fn clone_str(alloc: Allocator, str: []u8) []u8 {
        var new_str = alloc.alloc(u8, str.len) catch {
            @panic("Out Of memory");
        };

        std.mem.copy(u8, new_str, str);
        return new_str;
    }

    pub fn clone(self: *NutString, alloc: Allocator) *NutString {
        var new_nut_str = try alloc.create(NutString) catch {
            @panic("Out Of memory");
        };

        errdefer new_nut_str.deinit();

        new_nut_str.src = NutString.clone_str(self.src);
        return new_nut_str;
    }

    pub fn deinit(self: *NutString, alloc: Allocator) void {
        alloc.free(self.src);
        alloc.destroy(self);
    }
};


const NutNil = struct {

};

pub const NutUnion = union(ValueType) {
    Bool: bool,
    Number: f64,
    Nil: NutNil,
    String: *NutString,
};

pub const Value = struct {
    v_type: ValueType,
    value: NutUnion,
    is_on_heap: bool = false,

    pub fn bool_init(value: bool) Value {
        return .{ .v_type = .Bool, .value = .{ .Bool = value } };
    }

    pub fn number_init(value: f64) Value {
        return .{ .v_type = .Bool, .value = .{ .Number = value } };
    }

    pub fn value_new(allocator: Allocator, value: anytype) *Value {
        var val = allocator.create(Value) catch {
            @panic("Out Of memory");
        };
        val.is_on_heap = true;

        switch (@TypeOf(value)) {
            f64, i64 => {
                val.v_type = .Number;
                val.value = .{ .Number = value };
            },
            bool => {
                val.v_type = .Bool;
                val.value = .{ .Bool = value };
            },
            @TypeOf(null) => {
                val.v_type = .Nil;
            },
            []u8 => {
                val.v_type = .String;
                val.value = .{ .String = NutString.new(allocator, value) };
                val.is_on_heap = true;
            },
            *NutString => {
                val.v_type = .String;
                val.value = .{ .String = value };
            },
            else => @compileError("Can not coarse type to nut value"),
        }

        return val;
    }

    pub fn number_new(allocator: Allocator, value: f64) *Value {
        return value_new(allocator, value);
    }

    pub fn bool_new(allocator: Allocator, value: bool) *Value {
        return value_new(allocator, value);
    }

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.v_type) {
            .String => self.value.String.deinit(allocator),
            else => {},
        }
        if (self.is_on_heap) allocator.destroy(self);
    }

    pub fn as(self: *Value, comptime _type: ValueType) switch (_type) {
        .Bool => bool,
        .Number => f64,
        .Nil => null,
        .String => *NutString,
    } {
        return switch (_type) {
            .Bool => self.value.Bool,
            .Number => self.value.Number,
            .Nil => null,
            .String => self.value.String,
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


 

 

    pub fn print_this(self: *Value) void {
        switch (self.v_type) {
            .Bool => std.debug.print("{}", .{self.value.Bool}),
            .Nil => std.debug.print("Nil", .{}),
            .Number => std.debug.print("{d}", .{self.value.Number}),
            .String => std.debug.print("{s}", .{self.value.String.src}),
        }
    }
};

pub const ValueArray = ArrayList(*Value);

test "as" {
    var val = Value.number_init(12.3);
    std.debug.print("number is {}\n", .{val.as(.Number)});
}
