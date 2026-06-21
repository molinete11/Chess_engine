
const eval = @import("eval.zig");
const Board = @import("board.zig");
const uci = @import("uci.zig");
const std = @import("std");
const Io = std.Io;

fn negamax(board: *Board, depth: u32, max: u1, alpha: i32, beta: i32) i32{
    if(depth == 0){
        return eval.getEvaluation(board);
    }
    
    var move_list = board.generateMoves();

    if(board.isCheckMate()){
        return std.math.minInt(i32) + @as(i32, @bitCast(depth));
    }else if(board.isDraw()){
        return 0;
    }


    moveOrdering(&move_list);

    var bestScore: i32 = std.math.minInt(i32);
    var next_beta: i32 = beta;
    var next_alpha: i32 = alpha;

    for (0..move_list.count) |i| {
        board.makeMove(&move_list.moves[i]);
        bestScore = @max(-negamax(board, depth - 1, max ^ 1, next_alpha, next_beta), bestScore);
        board.unmakeMove(move_list.moves[i]);

        if(max == 1){
            next_alpha = bestScore;
            if(next_alpha >= beta) break;    

        }else{
            next_beta = -bestScore;
            if(alpha >= next_beta) break;
        }
    }

    return bestScore;
}

fn iterativeDeepening(io: Io, board: *Board, time: i64) ?Board.Move{

    var m = board.generateMoves();

    if(board.isCheckMate() or board.isDraw()){
        return null;
    }

    const current_time = time;
    var current_depth = 0;

    var best_move: Board.Move = undefined;
    var bestscore: i32 = std.math.minInt(i32);
    var best_move_idx: u8 = std.math.maxInt(u8);

    var alpha: i32 = std.math.minInt(i32);
    var beta: i32 = std.math.maxInt(i32);

    while(current_time > 0){
        if(best_move_idx != std.math.maxInt(u8)){
            const tmp = m.moves[0];
            m.moves[0] = m.moves[best_move_idx];
            m.moves[best_move_idx] = tmp;
        }

        for (0..m.count) |i| {
            var move = m.moves[i];
            const start = std.Io.Clock.awake.now(io);

            board.makeMove(&move);
            
            const score: i32 = -negamax(board, current_depth, @intFromEnum(board.to_play) ^ 1, alpha, beta);
            
            board.unmakeMove(move);

            const time_taken: i64 = (start.untilNow(io, .awake).toMilliseconds()) / 1000000000;
            _ = time_taken; // autofix
 
            std.debug.print("info {s} {}\n", .{uci.moveToUcimove(move), score});

            if (score >= bestscore) {
                best_move = move;
                bestscore = score;
                best_move_idx = @intCast(i);
            }

            if(board.to_play == .white){
                alpha = bestscore;
            }else{
                beta = -bestscore;
            } 
        }

            
            
        //current_time -= time_taken;
            

        current_depth += 1;
    }
}

pub fn getBestMove(board: *Board, depth: u32, wtime: u32, btime: u32, winc: u32, binc: u32, movetime: u32) ?Board.Move{

    // TODO: make iterative deepening 
    _ = wtime;
    _ = btime;
    _ = winc;
    _ = binc;
    _ = movetime;

    var m = board.generateMoves();

    if (board.isCheckMate() or board.isDraw()) {
        return null;
    }

    moveOrdering(&m);

    var bestoMove: Board.Move = undefined;
    var bestscore: i32 = std.math.minInt(i32);

    var alpha: i32 = std.math.minInt(i32);
    var beta: i32 = std.math.maxInt(i32);

    for (0..m.count) |i| {
        var move = m.moves[i];

        board.makeMove(&move);
        const score: i32 = -negamax(board, depth, @intFromEnum(board.to_play) ^ 1, alpha, beta);
        board.unmakeMove(move);

        std.debug.print("info {s} {}\n", .{uci.moveToUcimove(move), score});

        if (score >= bestscore) {
            bestoMove = move;
            bestscore = score;
        }

        if(board.to_play == .white){
            alpha = bestscore;
        }else{
            beta = -bestscore;
        } 
    }
    return bestoMove;
}

fn moveOrdering(move_list: *Board.MoveList) void{
    var i: usize = 0;
    
    for(i+1..move_list.count) |j|{

        if(move_list.moves[j].flags == .capture){

            const tmp = move_list.moves[i];

            move_list.moves[i] = move_list.moves[j];
            move_list.moves[j] = tmp;

            i += 1;
        }
    }
}

