const std = @import("std");
const vm = @import("vm.zig");
const chunk = @import("chunk.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const common = @import("common.zig");
const compiler = @import("compiler.zig");


const Nut = struct {
    args: [][:0]u8,
    allocator: Allocator,
    vm_: vm.Vm,

    pub fn init(allocator: Allocator) !Nut {
        return Nut{ 
            .args = try std.process.argsAlloc(allocator),
            .allocator = allocator,
            .vm_ = try vm.Vm.init(allocator)
        };
    }

    pub fn deinit(self: *Nut) void {
        self.vm_.deinit();
        std.process.argsFree(self.allocator, self.args);
    }

    pub fn main(self: *Nut) !void {
        if (self.args.len == 1) {
            try self.repl();
        } else if (self.args.len == 2) {
            try self.run_file();
        } else {
            self.usage();
        }
    }

    fn usage(_: *Nut) void {
        std.debug.print("nut <file>", .{});
    } 

    pub fn repl(self: *Nut) !void {
        while (true) {
            std.debug.print("nut > ", .{});
            if (try std.io.getStdIn().reader().readUntilDelimiterOrEofAlloc(self.allocator, '\n', 5120)) |line|{

                defer self.allocator.free(line);

                if (line.len == 0) {
                    continue;
                }

                if (std.mem.eql(u8, line, "exit")) {
                    break;
                }

                try self.interpret(line);
            }

        }
    }

    pub fn run_file(self: *Nut) !void {
        var source = try common.readFile(self.allocator, self.args[1]);
        defer self.allocator.free(source);

        try self.interpret(source);
    }

    pub fn interpret(self: *Nut, source: [] u8) !void {
        var cmp = compiler.Compiler.init(self.allocator);
        _ = try cmp.compile(source);
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    defer {
        if (gpa.deinit()) {
            std.debug.print("Memory Leaked !!!!!!!!!!!!!!!!\n", .{});
        }
    }

    var nut = try Nut.init(allocator);
    defer nut.deinit();

    try nut.main();
}
