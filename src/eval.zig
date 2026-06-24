const std = @import("std");
const Board = @import("board.zig");
const lookup_tables = @import("lookupTables.zig");
const PieceBitboardIdx = Board.PieceBitboardIdx;

const PAWN_VALUE: i32 = 100;
const KNIGHT_VALUE: i32 = 320;
const BISHOP_VALUE: i32 = 330;
const ROOK_VALUE: i32 = 500;
const QUEEN_VALUE: i32 = 900;

const activity_value: i32 = 2;


const PAWNS_HEURISTICS = [_]i32{
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, -20, -20, 10, 10, 5,
    5, -5,-10,  5, 5,-10, -5,  5,
    0,  0,  0, 30, 30,  0,  0,  0,
    5,  5, 10, 25, 25, 10,  5,  5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
     0,  0,  0,  0,  0,  0,  0,  0,
};

const KNIGHT_HEURISTICS = [_]i32{
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -35,  0, 15, 10, 10, 15,  0,-35,
    -35,  5, 10, 20, 20, 10,  5,-35,
    -35,  0, 10, 20, 20, 10,  0,-35,
    -35,  5, 15, 10, 10, 15,  5,-35,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-35,-35,-35,-35,-40,-50,
};
const BISHOP_HEURISTICS = [_]i32{
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -10, 10, 10, 3, 3, 10, 10,-10,
    -10,  0, 20, 10, 10, 20,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
};

const KING_HEURISTICS = [_]i32{ 
    120, 150, 100, 0, 0, 0, 150, 120, 
    5, 5, -5, -6, -6, -6, 5, 5, 
    -10, -10, -10, -10, -10, -10, -10, -10, 
    -50, -50, -50, -50, -50, -50, -50, -50, 
    -70, -70, -70, -70, -70, -70, -70, -70, 
    0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0 
    };

fn getPositionEval(board: *Board, white_pieces: []u64, black_pieces: []u64) i32 {
    var white_pos_eval: i32 = 0;

    const white_pieces_occ = board.bitboards[@intFromEnum(PieceBitboardIdx.white)];
    const black_pieces_occ = board.bitboards[@intFromEnum(PieceBitboardIdx.black)];
    const occ: u64 = board.bitboards[14];

    var wpawns = white_pieces[0];
    while (wpawns > 0) : (wpawns &= wpawns - 1) {
        white_pos_eval += @popCount(lookup_tables.getPawnMoves(@ctz(wpawns), 0) & ~white_pieces_occ) * activity_value;
        white_pos_eval += PAWNS_HEURISTICS[@ctz(wpawns)];
    }

    var wbishops = white_pieces[1];
    while (wbishops > 0) : (wbishops &= wbishops - 1) {
        white_pos_eval += @popCount(lookup_tables.getBishopMoves(@ctz(wbishops), occ) & ~white_pieces_occ) * activity_value;
        white_pos_eval += BISHOP_HEURISTICS[@ctz(wbishops)];
    }

    var wknights = white_pieces[2];
    while (wknights > 0) : (wknights &= wknights - 1) {
        white_pos_eval += @popCount(lookup_tables.getKnightMoves(@ctz(wknights)) & ~white_pieces_occ) * activity_value;
        white_pos_eval += KNIGHT_HEURISTICS[@ctz(wknights)];
    }

    var wrooks = white_pieces[3];
    while (wrooks > 0) : (wrooks &= wrooks - 1) {
        white_pos_eval += @popCount(lookup_tables.getRookMoves(@ctz(wrooks), occ) & ~white_pieces_occ) * activity_value;
    }

// ___________________________

    var black_pos_eval: i32 = 0;

    var bpawns = black_pieces[0];
    while (bpawns > 0) : (bpawns &= bpawns - 1) {
        black_pos_eval += @popCount(lookup_tables.getPawnMoves(@ctz(bpawns), 0) & ~black_pieces_occ) * activity_value;
        const sq: u6 = @intCast((7 - ((@ctz(bpawns) >> @intCast(3)))) * 8 + (@ctz(bpawns) & 7));
        black_pos_eval += PAWNS_HEURISTICS[sq];
    }

    var bbishops = black_pieces[1];
    while (bbishops > 0) : (bbishops &= bbishops - 1) {
        black_pos_eval += @popCount(lookup_tables.getBishopMoves(@ctz(bbishops), occ) & ~black_pieces_occ) * activity_value;
        const sq: u6 = @intCast((7 - ((@ctz(bbishops) >> @intCast(3)))) * 8 + (@ctz(bbishops) & 7));
        black_pos_eval += BISHOP_HEURISTICS[sq];
    }

    var bknights = black_pieces[2];
    while (bknights > 0) : (bknights &= bknights - 1) {
        black_pos_eval += @popCount(lookup_tables.getKnightMoves(@ctz(bknights)) & ~black_pieces_occ) * activity_value;
        black_pos_eval += KNIGHT_HEURISTICS[@ctz(bknights)];
    }

    var brooks = black_pieces[3];
    while (brooks > 0) : (brooks &= brooks - 1) {
        black_pos_eval += @popCount(lookup_tables.getRookMoves(@ctz(brooks), occ) & ~black_pieces_occ) * activity_value;
    }

    return white_pos_eval - black_pos_eval;
}

fn getMaterialEval(white_pieces: []u64, black_pieces: []u64) i32 {

    const white_pawns: i32 = @bitCast(@as(u32, @popCount(white_pieces[0])));
    const white_bishop: i32 = @bitCast(@as(u32, @popCount(white_pieces[1])));
    const white_knight: i32 = @bitCast(@as(u32, @popCount(white_pieces[2])));
    const white_rook: i32 = @bitCast(@as(u32, @popCount(white_pieces[3])));
    const white_queen: i32 = @bitCast(@as(u32, @popCount(white_pieces[4])));

    const black_pawns: i32 = @bitCast(@as(u32, @popCount(black_pieces[0])));
    const black_bishop: i32 = @bitCast(@as(u32, @popCount(black_pieces[1])));
    const black_knight: i32 = @bitCast(@as(u32, @popCount(black_pieces[2])));
    const black_rook: i32 = @bitCast(@as(u32, @popCount(black_pieces[3])));
    const black_queen: i32 = @bitCast(@as(u32, @popCount(black_pieces[4])));

    const w = @Vector(5, i32){ white_pawns, white_bishop, white_knight, white_rook, white_queen};

    const b = @Vector(5, i32){ black_pawns, black_bishop, black_knight, black_rook, black_queen};

    const e = @Vector(5, i32){ PAWN_VALUE, BISHOP_VALUE, KNIGHT_VALUE, ROOK_VALUE, QUEEN_VALUE };

    const res = (w - b) * e;

    return res[0] + res[1] + res[2] + res[3] + res[4];
}

pub fn getEvaluation(board: *Board) i32 {
    const white_pieces = board.bitboards[@intFromEnum(PieceBitboardIdx.wPawn)..(@intFromEnum(PieceBitboardIdx.wKing) + 1)];
    const black_pieces = board.bitboards[@intFromEnum(PieceBitboardIdx.bPawn)..(@intFromEnum(PieceBitboardIdx.bKing) + 1)];

    const material_eval = getMaterialEval(white_pieces, black_pieces);

    var whiteKingSafe: i32 = 0;
    var blackKingSafe: i32 = 0;


    whiteKingSafe += KING_HEURISTICS[@ctz(white_pieces[5])];

    const blackKingSq: u6 = @intCast((7 - ((@ctz(black_pieces[5]) >> @intCast(3)))) * 8 + (@ctz(black_pieces[5]) & 7));

    blackKingSafe += KING_HEURISTICS[blackKingSq];

    const pos_eval = getPositionEval(board, white_pieces, black_pieces);
    const kingSafe = whiteKingSafe - blackKingSafe;

    const whiteToPlay: i32 = if(board.to_play == .white) 1 else -1;

    return (material_eval + 
            pos_eval + 
            kingSafe
            ) * whiteToPlay;
}
