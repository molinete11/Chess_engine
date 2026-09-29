const std = @import("std");
const Board = @import("board.zig");
const Uci = @import("uci.zig");
const perft = @import("perft.zig").start;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "threefold repetition" {
    var board = Board.init();

    const moves  = [_][]const u8{"e2e4", "e7e5", "g1f3", "b8c6", "b1c3", "g8f6", "c3b1", "c6b8", "b1c3", "b8c6", "c3b1", "c6b8", "b1c3", "b8c6", "c3b1", "c6b8"};

    for(moves) |move|{
        board.playStringMove(move);
    }

    try expectEqual(0xbfef20101020efbf, board.bitboards[14]);
    try expectEqual(14, board.halfmove_clock);
    try expectEqual(true, board.isThreefoldRepetition());
}


test "perft" {

    var board = Board.init();

    try expect(perft(&board, 6, 0) == @as(u64, 119060324));

    board.setPos("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1") catch unreachable;
    try expect(perft(&board, 5, 0) == @as(u64, 193690690));
    
    board.setPos("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1") catch unreachable;
    try expect(perft(&board, 6, 0) == @as(u64, 11030083));

    board.setPos("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1") catch unreachable;
    try expect(perft(&board, 6, 0) == @as(u64, 706045033));

    board.setPos("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8") catch unreachable;
    try expect(perft(&board, 5, 0) == @as(u64, 89941194));
}

