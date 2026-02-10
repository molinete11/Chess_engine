const std = @import("std");
const bb = @import("bitboards.zig");



pub const std_options: std.Options =  .{    
   .log_level = .info,
};

pub fn main() void {
    bb.initBitBoards();

    std.debug.print("{}\n", .{bb.getBishopAttacks(18014398509744128, 0)});
    std.debug.print("{}\n", .{bb.getRookAttacks(1099528405040, 0)});
}


