const std = @import("std");
const NutError = error{ CompileError, RuntimeError };
const Allocator = std.mem.Allocator;

///caller owns the memory
pub fn readFile(allocator: Allocator, path: []u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    var stat = try file.stat();
    return try file.readToEndAlloc(allocator, stat.size);
}


pub const Mode = enum {
    RELEASE, DEBUG
};