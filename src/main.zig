const std = @import("std");
const bb = @import("bitboards.zig");



pub const std_options: std.Options =  .{    
   .log_level = .info,
};


pub fn main() !void {
    
    std.debug.print("Hello world\n", .{});
    bb.initBitBoards();
    std.debug.print("0x{X}\n", .{bb.rookMagicTable[0][1]});
}


