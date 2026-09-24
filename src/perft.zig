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
        const move = move_list.moves[i];
        board.makeMove2(move);
        const p = perft(board, depth - 1);
        //std.debug.print("0x{x} from {} to {}, flag {}\n", .{board.bitboards[Board.PieceBitboardIdx.toInt(.wRook)], move.from(), move.to(), move.flag()});
        std.debug.print("move {s} nodes {}\n", .{Uci.moveToUcimove(move), p});
        tot += p;
        board.unmakeMove2(move);
    }
    std.debug.print("{}\n", .{tot});
}

fn perft(board: *Board, depth: u32) u64{
    if(depth == 0){
        return @as(u64, 1);
    }

    var nodes: u64 = 0;
    const moveList = board.generateMoves();

    if(depth == 1){
        return moveList.count;
    }

    for(0..moveList.count) |i|{
        //std.debug.print("{}\n", .{i});

        board.makeMove2(moveList.moves[i]);

        nodes += perft(board, depth - 1);

        board.unmakeMove2(moveList.moves[i]);
    }

    return nodes;
}
