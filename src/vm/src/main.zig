const std = @import("std");
const vm = @import("vm.zig");
const chunk = @import("chunk.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    defer {
        if (gpa.deinit()) {
            std.debug.print("Memory Leaked !!!!!!!!!!!!!!!!", .{});
        }
    }

    var _vm = try vm.Vm.init(allocator);
    var _chunk = try chunk.Chunk.new(allocator);
    defer _chunk.deinit();

    var constant = try _chunk.add_constant(1.2);
    try _chunk.write_chunk(.LOAD_CONST, 12);
    try _chunk.write_u8(@intCast(u8, constant));

    constant = try _chunk.add_constant(3.4);
    try _chunk.write_chunk(.LOAD_CONST, 12);
    try _chunk.write_u8(@intCast(u8, constant));

    try _chunk.write_chunk(.ADD, 12);

    constant = try _chunk.add_constant(4.6);
    try _chunk.write_chunk(.LOAD_CONST, 12);
    try _chunk.write_u8(@intCast(u8, constant));

    try _chunk.write_chunk(.DIVIDE, 12);
    try _chunk.write_chunk(.NEGATE, 12);

    try _chunk.write_chunk(.RETURN, 12);

    // try _chunk.disassemble_chunk("test chunk");

    try _vm.interpret(_chunk);
    std.debug.print("stack top: {d}\n", .{_vm.stack.pop()});
    defer _vm.deinit();
}
