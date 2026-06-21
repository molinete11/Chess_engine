const std = @import("std");
const Board = @import("board.zig");
const Uci = @import("uci.zig");
const expect = std.testing.expect;

pub fn start(board: *Board, depth: u32, opt: u2) ?u64{
    switch (opt) {
        0 => return perft(board, depth),
        1 => {perftDivide(board, depth); return null;},
        else => return @as(u64, 0)
    }
}

fn perftDivide(board: *Board, depth: u32) void{
    const move_list = board.generateMoves();
    var tot: u64 = 0;

    for(0..move_list.count) |i|{
        var move = move_list.moves[i];
        board.makeMove(&move);
        const p = perft(board, depth - 1);
        std.debug.print("{s}\n", .{Uci.moveToUcimove(move)});
        tot += p;
        board.unmakeMove(move);
    }
    std.debug.print("{}\n", .{tot});
}

fn perft(board: *Board, depth: u32) u64{
    if(depth == 0){
        return @as(u64, 1);
    }

    var nodes: u64 = 0;
    var moveList = board.generateMoves();

    if(depth == 1){
        return moveList.count;
    }

    for(0..moveList.count) |i|{

        board.makeMove(&moveList.moves[i]);

        nodes += perft(board, depth - 1);

        board.unmakeMove(moveList.moves[i]);
    }

    return nodes;
}



test "perft" {

    var board = Board.init();

    try expect(perft(&board, 6) == @as(u64, 119060324)); // start pos

    board.setPos("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1");
    try expect(perft(&board, 5) == @as(u64, 193690690));
    
    board.setPos("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
    try expect(perft(&board, 6) == @as(u64, 11030083));

    board.setPos("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1");
    try expect(perft(&board, 6) == @as(u64, 706045033));

    board.setPos("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8");
    try expect(perft(&board, 5) == @as(u64, 89941194));

}