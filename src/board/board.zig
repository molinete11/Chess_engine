const std = @import("std");
const movegen = @import("movegen.zig");
pub const Position = @import("position.zig");
pub const MoveList = @import("moveList.zig");
pub const Move = @import("move.zig");

const Self = @This();

pub const default_fen: []const u8 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

position: Position,

pub fn init() Self{
    return .{
        .position = .init()
    };
}

pub fn generateMoves(self: *Self, comptime T: movegen.MoveType) MoveList{
    return movegen.genMoves(&self.position, T);
}





