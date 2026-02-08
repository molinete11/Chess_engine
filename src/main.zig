const std = @import("std");
const bb = @import("bitboards.zig");



pub const std_options: std.Options =  .{    
   .log_level = .info,
};

pub fn main() !void {
    std.debug.print("0x{X}\n", .{bb.rookMagicTable[0][4095]});
    std.debug.print("0x{X}\n", .{bb.bishopMagicTable[5][356]});
}


