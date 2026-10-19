const std = @import("std");
const perft = @import("perft.zig");
const Board = @import("board.zig");


pub fn runBench(io: std.Io) !void{
    var board = Board.init();

    try runPerft(&board, "start pos", Board.default_fen, 6, io);    

    try runPerft(&board, "Kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 5, io);

    try runPerft(&board, "pos 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", 7, io);

    try runPerft(&board, "pos 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 6, io);

    try runPerft(&board,"pos 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", 5, io);
}

fn runPerft(board: *Board, testName: []const u8, pos: []const u8, depth: u32, io: std.Io) !void{
    board.setPos(pos) catch unreachable;
    const start = std.Io.Clock.awake.now(io);
    
    const n = perft.start(board, depth, 0).?;
    
    const time: f64 = @as(f64, @floatFromInt(start.untilNow(io, .awake).toNanoseconds())) / @as(f64, 1000000000);
    std.log.info("{s}:\n nodes = {}, time(s) = {}, nps = {}, depth = {}", .{
        testName,
        n, 
        time, 
        @as(f64, @floatFromInt(n)) / time,
        depth});   
}