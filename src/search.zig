
const eval = @import("eval.zig");
const Board = @import("board.zig");
const Move = @import("move.zig");
const MoveList = @import("moveList.zig");
const uci = @import("uci.zig");
const std = @import("std");
const Io = std.Io;

const SearchResult = struct {
    move: Move,
    eval: i32,
};


const check_mate_value: i32 = -999_999_999;

const PvLine = struct{
    count: u8,
    moves: [218]Move,
};

fn negamax(board: *Board, depth: u32, alpha: i32, beta: i32, time_left: i64, io: Io, pv_line: *PvLine) i32{
    var move_list = board.generateMoves();

    var _pv_line: PvLine = .{
        .count = 0,
        .moves = undefined,
    };

    if(depth == 0 or board.isCheckMate() or board.isDraw())
    {
        if(board.isCheckMate()){
            return check_mate_value - @as(i32, @bitCast(depth));
        }else if(board.isDraw()){
            return 0;
        }

        return eval.getEvaluation(board);
    }

    moveOrdering(&move_list);

    var bestScore: i32 = std.math.minInt(i32);
    var next_alpha: i32 = alpha;

    var time_left_c = time_left;

    for (0..move_list.count) |i| {
        const clock = std.Io.Clock.awake.now(io);

        board.makeMove(&move_list.moves[i]);
        const oponent_score = negamax(
            board, 
            depth -% 1, 
            -beta, 
            -next_alpha, 
            time_left_c, 
            io,
            &_pv_line
            );
        board.unmakeMove(move_list.moves[i]);

        bestScore = @max(-oponent_score, bestScore);

        if(oponent_score == std.math.maxInt(i32)){ // no time left
            return std.math.maxInt(i32);
        }

        if(bestScore >= beta) break;
        if(bestScore > next_alpha) {
            next_alpha = bestScore;
            pv_line.moves[0] = move_list.moves[i];

            //for(0.._pv_line.count) |j|{
            //    pv_line.moves[j + 1] = _pv_line.moves[j];
            //}

            if(_pv_line.count != 0){
                std.debug.assert(pv_line.moves[1.._pv_line.count+1].len == _pv_line.moves[0.._pv_line.count].len);
                @memcpy(pv_line.moves[1.._pv_line.count+1], _pv_line.moves[0.._pv_line.count]);
            }
            

            pv_line.count = _pv_line.count + 1;

        }    

        const time_spend = clock.untilNow(io, .awake);
        time_left_c -= time_spend.toMilliseconds();

        if(time_left_c <= 0){
            return std.math.maxInt(i32);
        }
    }

    return bestScore;
}

fn iterativeDeepening(io: Io, board: *Board, time: i64) SearchResult{ 
    var time_allocated = time;
    var move_list = board.generateMoves();
    moveOrdering(&move_list);

    var current_best_move = std.mem.zeroes(Move);
    var current_best_move_eval: i32 = std.math.minInt(i32);

    var time_spend_between_plys: i64 = 0;

    var depth: u32 = 0;

    while(true){
        var current_ply_best_move = std.mem.zeroes(Move);
        var current_ply_best_move_eval: i32 = std.math.minInt(i32);

        var main_pv_line: PvLine = .{
            .count = 0,
            .moves = undefined,
        };

        var alpha: i32 = std.math.minInt(i32) + 1;

        for(0..move_list.count) |i|{
            var pv_line: PvLine = .{
                .count = 0,
                .moves = undefined,
            };
            
            const clock = std.Io.Clock.awake.now(io);

            var move = move_list.moves[i];

            //std.debug.print("move played {s}\n", .{uci.moveToUcimove(move)});

            board.makeMove(&move);
            const current_move_eval = -negamax(board, 
                                                    depth,
                                                    std.math.minInt(i32) + 1,
                                                    -alpha,
                                                    time_allocated, 
                                                    io,
                                                    &pv_line);
            board.unmakeMove(move);

            if(current_move_eval == std.math.maxInt(i32)){
                return .{
                    .move = current_best_move,
                    .eval = current_best_move_eval
                };
            }

            if(current_move_eval > current_ply_best_move_eval){
                current_ply_best_move = move;
                current_ply_best_move_eval = current_move_eval;

                if(current_ply_best_move_eval > alpha){
                    alpha = current_ply_best_move_eval;
                
                    @memcpy(main_pv_line.moves[0..pv_line.count], pv_line.moves[0..pv_line.count]);
                    
                    main_pv_line.count = pv_line.count;
                }
            }

            const time_spend = clock.untilNow(io, .awake);
        

            time_spend_between_plys +%= time_spend.toMilliseconds();
            time_allocated -= time_spend.toMilliseconds();
            
            if(time_allocated <= 0){
                break;
            }
        }

        if(time_allocated <= 0){
            std.debug.print("not finished, best move found {s} eval {}\n", .{
                uci.moveToUcimove(current_best_move),
                current_best_move_eval});

            for(0..main_pv_line.count) |j|{
                std.log.debug(" {s} ", .{uci.moveToUcimove(main_pv_line.moves[j])});
            }

            std.log.debug("\n", .{});

            break;
        }else{
            std.debug.print("time spend {}ms, time_left {}ms, current depth {} best move found {s} eval {}\n", .{
                time_spend_between_plys, 
                time_allocated, 
                depth,
                uci.moveToUcimove(current_ply_best_move),
                current_ply_best_move_eval});

            for(0..main_pv_line.count) |j|{
                std.debug.print(" {s} ", .{uci.moveToUcimove(main_pv_line.moves[j])});
            }

            std.debug.print("\n", .{});
        }

        current_best_move = current_ply_best_move;
        current_best_move_eval = current_ply_best_move_eval;
        depth += 1;
        time_spend_between_plys = 0;
    }

    return .{
        .move = current_best_move,
        .eval = current_best_move_eval,
    };
}

pub fn getBestMove(io: Io, board: *Board, depth: u32, wtime: i32, btime: i32, winc: i32, binc: i32, movetime: u32) []u8{

    // TODO: make iterative deepening 

    _ = movetime;
    _ = depth;

    var allocated_time: i64 = 0;

    if(board.to_play == .white){
        allocated_time = @divFloor(wtime, 20) + @divFloor(winc, 2);
    }else{
        allocated_time = @divFloor(btime, 20) + @divFloor(binc, 2);
    }

    const search_result = iterativeDeepening(io, board, allocated_time);

    std.log.debug("bestmove {s} eval {}\n", .{uci.moveToUcimove(search_result.move), search_result.eval});

    return uci.moveToUcimove(search_result.move);
}

fn moveOrdering(move_list: *MoveList) void{
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

