const std = @import("std");
const bb = @import("bitboards.zig");

pub const std_options: std.Options =  .{    
   .log_level = .info,
};


pub fn main() !void {
    std.debug.print("Hello world\n", .{});
    bb.initBitBoards();
    
}


