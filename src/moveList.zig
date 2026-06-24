const Move = @import("move.zig");

const Self = @This();

moves: [218]Move,
count: u8,

pub inline fn Init() Self{
    return .{
        .count = 0,
        .moves = undefined,
    };
}

pub inline fn add(self: *Self, move: Move) void{
    self.moves[self.count] = move;
    self.count += 1;
}

