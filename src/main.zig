const std = @import("std");
const bb = @import("bitboards.zig");


pub fn main() !void {
    std.debug.print("Hello world\n", .{});
    bb.initBitBoards();
    
}


