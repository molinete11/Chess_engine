const Move = @import("move.zig");

const Self = @This();

moves: [218]Move,
score: [218]u8,
count: u8,

pub inline fn Init() Self{
    return .{
        .count = 0,
        .score = undefined,
        .moves = undefined,
    };
}

pub inline fn add(self: *Self, move: Move) void{
    self.moves[self.count] = move;
    self.count += 1;
}

pub inline fn empty(self: *const Self) bool{
    return self.count == 0;
}

