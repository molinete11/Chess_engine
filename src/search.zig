
const eval = @import("eval.zig");
const Board = @import("board/board.zig");

const uci = @import("uci.zig");
const std = @import("std");
const Io = std.Io;
const Move = Board.Move;
const MoveList = Board.MoveList;

const SearchResult = struct {
    move: Move,
    eval: i32,
};

const check_mate_value: i32 = -999_999_999;

const PvLine = struct{
    count: u8,
    moves: [218]Move,
};

const mvv_lva = [_][5] u8{
    .{14, 13, 12, 11, 10},
    .{24, 23, 22, 21, 20},
    .{34, 33, 32, 31, 30},
    .{44, 43, 42, 41, 40},
    .{7 , 53, 52, 51, 50},
    .{0, 0, 0, 0, 0}
};

fn qsearch(board: *Board, alpha: i32, beta: i32) i32{
    const pos = &board.*.position;
    const static_eval = eval.getEvaluation(pos);

    var bestmove: i32 = static_eval;
    var new_alpha: i32 = alpha;

    if(bestmove >= beta) return bestmove;
    if(bestmove > alpha) {
        new_alpha = bestmove;
    }

    var move_list: MoveList = undefined;

    if(pos.isKingInCheck(pos.to_play, pos.occupancy(.both))){
        move_list = board.generateMoves(.all);

        if(move_list.count == 0){
            if(pos.isKingInCheck(pos.to_play, pos.notEmpty())){
                return check_mate_value;
            }else{
                return 0;
            }
        }
    }else{
        move_list = board.generateMoves(.captures);
    }

    moveOrdering(&move_list, board);

    for(0..move_list.count) |i|{
        pickMove(&move_list, i);
        const move = move_list.moves[i];

        pos.makeMove2(move);

        const score: i32 = -qsearch(board, -beta, -new_alpha);

        pos.unmakeMove2(move);

        if(score >= beta) return score;
        if(score > new_alpha){
            new_alpha = score;
        }
        if(score > bestmove){
            bestmove = score;
        }
    }

    return bestmove;
}

fn isThreefoldRepetition(board: *const Board) bool {
    var n: u32 = 1;

    const pos = &board.position;

    var halfmove_clock: u32 = pos.halfmove_clock;

    if (halfmove_clock < 4) {
        return false;
    }

    halfmove_clock = @min(halfmove_clock, pos.ply);

    var i: u32 = 2;

    while (i <= halfmove_clock) : (i += 2) {
        const undo = pos.position_history[pos.ply - i];

        if (undo.key == pos.key) {
            n += 1;
        }

        if (n >= 3) {
            return true;
        }
    }

    return false;
}

fn negamax(board: *Board, depth: u32, alpha: i32, beta: i32, time_left: i64, io: Io, pv_line: *PvLine, nodes: *u64) i32{
    nodes.* += 1;

    var _pv_line: PvLine = .{
        .count = 0,
        .moves = undefined,
    };

    var pos = &board.*.position;

    if(pos.halfmove_clock >= 100 or isThreefoldRepetition(board)){
        return 0;
    }

    if(depth == 0){
        return qsearch(board, alpha, beta);
    }

    var move_list = board.generateMoves(.all);

    if(move_list.empty()){
        if(pos.isKingInCheck(pos.to_play, pos.notEmpty())){
            return check_mate_value - @as(i32, @bitCast(depth));
        }else{
            return 0;
        }
    }

    moveOrdering(&move_list, board);

    var bestScore: i32 = std.math.minInt(i32);
    var next_alpha: i32 = alpha;

    var time_left_c = time_left;

    for (0..move_list.count) |i| {
        const clock = std.Io.Clock.awake.now(io);

        pickMove(&move_list, i);

        pos.makeMove2(move_list.moves[i]);   

        const oponent_score = negamax(
            board, 
            depth -% 1, 
            -beta, 
            -next_alpha, 
            time_left_c, 
            io,
            &_pv_line,
            nodes
            );

        pos.unmakeMove2(move_list.moves[i]);

        bestScore = @max(-oponent_score, bestScore);

        if(oponent_score == std.math.maxInt(i32)){ // no time left
            return std.math.maxInt(i32);
        }

        if(bestScore >= beta) break;
        if(bestScore > next_alpha) {
            next_alpha = bestScore;
            pv_line.moves[0] = move_list.moves[i];

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

fn iterativeDeepening(io: Io, board: *Board, time: i64, depth: u32) ?SearchResult{ 
    var time_allocated = time;
    var move_list = board.generateMoves(.all);
    var pos = &board.*.position;
    if(move_list.empty()) return null;
    moveOrdering(&move_list, board);

    var current_best_move = std.mem.zeroes(Move);
    var current_best_move_eval: i32 = std.math.minInt(i32);

    var time_spend_between_plys: i64 = 0; 

    for(1..depth)|c_depth|{
        var total_nodes: u64 = 0;
        var current_ply_best_move = std.mem.zeroes(Move);
        var current_ply_best_move_eval: i32 = std.math.minInt(i32);

        var main_pv_line: PvLine = .{
            .count = 0,
            .moves = undefined,
        };

        var alpha: i32 = std.math.minInt(i32) + 1;

        for(0..move_list.count) |i|{
            var nodes: u64 = 0;
            var pv_line: PvLine = .{
                .count = 0,
                .moves = undefined,
            };
            
            const clock = std.Io.Clock.awake.now(io);

            pickMove(&move_list, i);

            const move = move_list.moves[i];

            //std.debug.print("move played {s}\n", .{uci.moveToUcimove(move)});

            pos.makeMove2(move);
            
            const current_move_eval = -negamax(board, 
                                                    @intCast(c_depth),
                                                    std.math.minInt(i32) + 1,
                                                    -alpha,
                                                    time_allocated, 
                                                    io,
                                                    &pv_line,
                                                    &nodes);
            pos.unmakeMove2(move);

            total_nodes += nodes;

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
            //std.debug.print("not finished, best move found {s} eval {}\n", .{
            //    uci.moveToUcimove(current_best_move),
            //    current_best_move_eval});
            break;
        }else{
            std.debug.print("time spend {}ms, time_left {}ms, current depth {} best move found {s} eval {} tot nodes {}\n", .{
                time_spend_between_plys, 
                time_allocated, 
                c_depth,
                uci.moveToUcimove(current_ply_best_move),
                current_ply_best_move_eval,
                total_nodes});

            for(0..main_pv_line.count) |j|{
                std.debug.print(" {s} ", .{uci.moveToUcimove(main_pv_line.moves[j])});
            }

            std.debug.print("\n", .{});
        }

        current_best_move = current_ply_best_move;
        current_best_move_eval = current_ply_best_move_eval;
        time_spend_between_plys = 0;
        total_nodes = 0;
    }

    return .{
        .move = current_best_move,
        .eval = current_best_move_eval,
    };
}

fn moveOrdering(move_list: *MoveList, board: *Board) void{
    if(move_list.empty()) return;
    for(0..move_list.count) |i|{
        const move = move_list.moves[i];
        const captured = board.position.bitboard_idx[move.to()];
        const attacker = board.position.bitboard_idx[move.from()];
        move_list.score[i] = mvv_lva[captured.toInt()][attacker.toInt()];
    }
}

fn pickMove(move_list: *MoveList, i: usize) void{
    var best_move = move_list.score[i];
    var idx: usize = i;

    for(i..move_list.count) |j|{
        if(move_list.score[j] > best_move){
            best_move = move_list.score[j];
            idx = j;
        }
    }

    std.mem.swap(Move, &move_list.moves[i], &move_list.moves[idx]);
    std.mem.swap(u8, &move_list.score[i], &move_list.score[idx]);
}

pub fn getBestMove(io: Io, board: *Board, depth: u32, wtime: i32, btime: i32, winc: i32, binc: i32, movetime: u32) ?[]u8{

    _ = movetime;

    var allocated_time: i64 = 0;

    if(board.position.to_play == .white){
        allocated_time = @divFloor(wtime, 20) + @divFloor(winc, 2);
    }else{
        allocated_time = @divFloor(btime, 20) + @divFloor(binc, 2);
    }

    const search_result = iterativeDeepening(io, board, allocated_time, depth);

    if(search_result) |res|{
         std.log.debug("bestmove {s} eval {}\n", .{uci.moveToUcimove(res.move), res.eval});
         return uci.moveToUcimove(res.move);
    }else{
        std.log.debug("bestmove null\n", .{});
        return null;
    }
}
