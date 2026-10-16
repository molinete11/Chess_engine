const std = @import("std");
const Uci = @import("uci.zig");


pub fn main(init: std.process.Init) !void {

    var uci = try Uci.Init(init.io, init.gpa);

    try uci.run();
}
