const std = @import("std");
const lookup_tables = @import("lot.zig");
const bit_set = @import("bitSet.zig");
const Move = @import("move.zig");
const MoveList = @import("moveList.zig");
const zobristHash = @import("zobristHash.zig");

const assert = std.debug.assert;

const Self = @This();

pub const Side = enum(u2) {
    white,
    black,
    both,

    pub fn change(self: *@This()) void {
        self.* = if (self.* == .white) .black else .white;
    }

    pub fn toInt(self: @This()) u2 {
        return @backingInt(self);
    }

    pub fn enemy(self: @This()) @This() {
        return @fromBackingInt(self.toInt() ^ 1);
    }
};

pub const Piece = enum(u4) {
    pawn,
    bishop,
    knight,
    rook,
    queen,
    king,
    none,

    pub inline fn toInt(self: @This()) u4 {
        return @backingInt(self);
    }
};

const PieceStoreMoveInfo = struct {
    legalSquares: u64,
    legalCaptures: u64,
    from: u6,
};

const MoveSetList = struct {
    moveSets: [18]u64,
    from: [18]u6,
    count: u6,

    pub fn add(self: *@This(), moveSet: u64, from: u6) void {
        self.moveSets[self.count] = moveSet;
        self.from[self.count] = from;
        self.count += 1;
    }
};

const FenError = error{
    InvalidFen,
};

const Undo = struct {
    key: u64,
    halfmove_clock: u32,
    ep_square: u6,
    castle_rights: u4,
    capture: Piece,
};

pub const notAFile: u64 = 0xfefefefefefefefe;
pub const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
pub const notABFile: u64 = 0xfcfcfcfcfcfcfcfc;
pub const notHGFile: u64 = 0x3f3f3f3f3f3f3f3f;
pub const aFile: u64 = 0x0101010101010101;
pub const bFile: u64 = 0x202020202020202;
pub const rank1: u64 = 0x00000000000000FF;
pub const rank2: u64 = 0x000000000000FF00;
pub const rank3: u64 = 0x0000000000FF0000;
pub const rank4: u64 = 0x00000000FF000000;
pub const rank5: u64 = 0x000000FF00000000;
pub const rank6: u64 = 0x0000FF0000000000;
pub const rank7: u64 = 0x00FF000000000000;
pub const rank8: u64 = 0xFF00000000000000;
pub const mDiagonal: u64 = 0x8040201008040201;
pub const aDiagonal: u64 = 0x102040810204080;

pub const default_fen: []const u8 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

const max_move_game: u16 = 512;

position_history: [max_move_game]Undo,

bitboards: [2][6]u64,
sides: [3]u64,

bitboard_idx: [64]Piece,

key: u64,

ply: u16,

halfmove_clock: u32,

move_number: u16,

en_passant_sq: u6,

castle_rights: u4, // bit 1 = K, bit 2 = Q, bit 3 = k, bit 4 = q

to_play: Side,

pub fn init() Self {
    var board = std.mem.zeroes(Self);

    board.setPos(default_fen) catch unreachable;

    return board;
}

pub fn setPos(self: *Self, fen: []const u8) !void {
    self.clearBoard();

    var fenTokens = std.mem.splitAny(u8, fen, " ");

    const fenBoard = fenTokens.first();

    var rank: u8 = 7;
    var file: u8 = 0;

    for (0..fenBoard.len) |i| {
        if (fenBoard[i] == '/') {
            rank -= 1;
            file = 0;
            continue;
        } else if (std.ascii.isDigit(fenBoard[i])) {
            if (fenBoard[i] == '9' or fenBoard[i] == '0') {
                return FenError.InvalidFen;
            }
            file += fenBoard[i] & 0xF;
            continue;
        }

        const sq: usize = @intCast(rank * 8 + file);

        const piece: Piece = switch (fenBoard[i]) {
            'p', 'P' => .pawn,
            'b', 'B' => .bishop,
            'n', 'N' => .knight,
            'r', 'R' => .rook,
            'q', 'Q' => .queen,
            'k', 'K' => .king,
            else => .none,
        };

        const side: Side = if(std.ascii.isUpper(fenBoard[i])) .white else .black;

        self.putPiece(side, piece, sq);

        file += 1;
    }

    const whiteToPlay = fenTokens.next().?;

    if (std.mem.eql(u8, whiteToPlay, "w")) {
        self.to_play = .white;
        self.key ^= zobristHash.side_keys[0];
    } else if (std.mem.eql(u8, whiteToPlay, "b")) {
        self.to_play = .black;
        self.key ^= zobristHash.side_keys[1];
    } else {
        return FenError.InvalidFen;
    }

    const castleRights = fenTokens.next().?;

    for (0..castleRights.len) |i| {
        switch (castleRights[i]) {
            'K' => {
                self.castle_rights ^= 0x1;
                self.key ^= zobristHash.castling_rights[0];
            },
            'Q' => {
                self.castle_rights ^= 0x2;
                self.key ^= zobristHash.castling_rights[1];
            },
            'k' => {
                self.castle_rights ^= 0x4;
                self.key ^= zobristHash.castling_rights[2];
            },
            'q' => {
                self.castle_rights ^= 0x8;
                self.key ^= zobristHash.castling_rights[3];
            },
            else => {},
        }
    }

    const enPassantSquare = fenTokens.next().?;

    if (!std.mem.eql(u8, enPassantSquare, "-")) {
        const fileFrom: u10 = enPassantSquare[0] - 'a';
        const rankFrom: u10 = enPassantSquare[1] - '1';
        const sq: u10 = rankFrom * 8 + fileFrom;

        self.key ^= zobristHash.ep_file[fileFrom];

        if (!(rankFrom == 7 or rankFrom == 3)) {
            return FenError.InvalidFen;
        }

        self.en_passant_sq = @intCast(sq);
    }
}

test "load_fen" {
    var board = Self.init();
    try std.testing.expectEqual(@as(u64, 0xffff00000000ffff), board.notEmpty());
    try std.testing.expectEqual(@as(u64, 0xffff000000000000), board.occupancy(.black));
    try std.testing.expectEqual(@as(u64, 0xffff), board.occupancy(.white));

    board.setPos("r1bqkb1r/pp2ppp1/2np1n1p/6B1/3NP3/2N5/PPP2PPP/R2QKB1R w KQkq - 0 7") catch {};

    try std.testing.expectEqual(@as(u64, 0xbd73ac401804e7b9), board.notEmpty());
    try std.testing.expectEqual(@as(u64, 0xbd73ac0000000000), board.occupancy(.black));
    try std.testing.expectEqual(@as(u64, 0x401804e7b9), board.occupancy(.white));

}

pub inline fn putPiece(self: *Self, side: Side, piece: Piece, sq: usize) void{
    assert(sq >= 0 or sq <= 63); assert(piece != .none); assert(side != .both);
    const square_mask =  @as(u64, 1) << @as(u6, @intCast(sq)); 
    self.bitboards[side.toInt()][piece.toInt()] ^= square_mask;
    self.sides[side.toInt()] ^= square_mask;
    self.sides[Side.toInt(.both)] ^= square_mask;
    self.bitboard_idx[sq] = piece;
    self.key ^= zobristHash.keys[side.toInt()][piece.toInt()][sq];
}

pub inline fn pieces(self: *const Self, side: Side) []const u64{
    return &self.bitboards[side.toInt()];
}

pub inline fn pieceSet(self: *const Self, side: Side, piece: Piece) u64{
    return self.pieces(side)[piece.toInt()];
}

pub inline fn teamPieces(self: *const Self) []const u64{
    return self.pieces(self.to_play);
}

pub inline fn enemyPieces(self: *const Self) []const u64{
    return self.pieces(self.to_play.enemy());
}

pub inline fn occupancy(self: *const Self, side: Side) u64{
    return self.sides[side.toInt()];
}

pub inline fn teamOccupancy(self: *const Self) u64{
    return self.occupancy(self.to_play);
}

pub inline fn enemyOccupancy(self: *const Self) u64{
    return self.occupancy(self.to_play.enemy());
}

pub inline fn notEmpty(self: *const Self) u64{
    return self.occupancy(.both);
}

pub inline fn empty(self: *const Self) u64{
    return ~self.notEmpty();
}

pub fn restartPos(self: *Self) void {
    self.setPos(default_fen) catch unreachable;
}

pub fn getFen(self: *const Self) [92]u8 {
    _ = self;

    const fen: [92]u8 = @splat(0);

    return fen;
}

inline fn clearBoard(self: *Self) void {
    self.bitboards[0] = @splat(0);
    self.bitboards[1] = @splat(0);
    self.sides = @splat(0);
    for (0..64) |i| { 
        self.bitboard_idx[i] = .none;
    }
    self.castle_rights = 0;
    self.en_passant_sq = 0;
    self.ply = 0;
    self.key = 0;
    self.to_play = .white;
}

pub fn isThreefoldRepetition(self: *const Self) bool {
    var n: u32 = 1;

    if (self.halfmove_clock < 4) {
        return false;
    }

    const halfmove_clock: u32 = @min(self.halfmove_clock, self.ply);

    var i: u32 = 2;

    while (i <= halfmove_clock) : (i += 2) {
        const undo = self.position_history[self.ply - i];

        if (undo.key == self.key) {
            n += 1;
        }

        if (n >= 3) {
            return true;
        }
    }

    return false;
}

pub fn isFiftyMoveRule(self: *const Self) bool {
    return self.halfmove_clock >= 100;
}

pub fn makeMove2(self: *Self, move: Move) void {
    const from = move.from();
    const to = move.to();

    const fromU64 = @as(u64, 1) << from;
    const toU64 = @as(u64, 1) << to;
    const from_toU64 = fromU64 | toU64;

    const from_rank = from >> 3;
    const from_file = from & 7;

    const to_rank = to >> 3;
    const to_file = to & 7;

    const team_piece_idx = self.bitboard_idx[from];
    const team_color_idx: Side = if (self.isWhiteToPlay()) .white else .black;

    const enemy_piece_idx = self.bitboard_idx[to];
    const enemy_color_idx: Side = if (self.isWhiteToPlay()) .black else .white;

    self.position_history[self.ply].key = self.key;
    self.position_history[self.ply].ep_square = self.en_passant_sq;
    self.position_history[self.ply].castle_rights = self.castle_rights;
    self.position_history[self.ply].capture = enemy_piece_idx;
    self.position_history[self.ply].halfmove_clock = self.halfmove_clock;

    std.debug.assert(team_piece_idx != .none);
    std.debug.assert(self.to_play != .both);

    self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= from_toU64;
    self.sides[team_color_idx.toInt()] ^= from_toU64;
    self.bitboard_idx[to] = team_piece_idx;
    self.bitboard_idx[from] = .none;

    if (self.en_passant_sq != 0) {
        self.key ^= zobristHash.ep_file[self.en_passant_sq & 7];
    }
    self.en_passant_sq = 0;

    self.key ^= zobristHash.keys[self.to_play.toInt()][team_piece_idx.toInt()][from];
    self.key ^= zobristHash.keys[self.to_play.toInt()][team_piece_idx.toInt()][to];

    self.halfmove_clock += 1;

    self.halfmove_clock = if (team_piece_idx == .pawn) 0 else self.halfmove_clock;

    switch (move.flag()) {
        .capture => {
            //self.position_history[self.ply].capture = enemy_piece_idx;
            self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
            self.sides[enemy_color_idx.toInt()] ^= toU64;
            self.key ^= zobristHash.keys[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()][to];
            self.halfmove_clock = 0;
        },
        .doublePawnPush => {
            if(self.isWhiteToPlay()){
                self.en_passant_sq = to - 8;
            }else{
                self.en_passant_sq = to + 8;
            }
            self.key ^= zobristHash.ep_file[self.en_passant_sq & 7];
        },
        .epCapture => {
            var sq: u6 = 0;
            if(self.isWhiteToPlay()){
                sq = to - 8;
            }else{
                sq = to + 8;
            }
            const ep_sqU64 = (@as(u64, 1) << (sq));
            const enemy_pawn_piece_idx: Piece = .pawn;
            self.bitboard_idx[sq] = .none;
            self.key ^= zobristHash.keys[self.to_play.enemy().toInt()][enemy_pawn_piece_idx.toInt()][@ctz(ep_sqU64)];
            self.halfmove_clock = 0;

            self.position_history[self.ply].capture = enemy_pawn_piece_idx;

            self.bitboards[self.to_play.enemy().toInt()][enemy_pawn_piece_idx.toInt()] ^= ep_sqU64;
            self.sides[enemy_color_idx.toInt()] ^= ep_sqU64;
        },
        .kingSideCastle => {
            const team_rook_idx: Piece = .rook;
            const rook_moveU64 = from_toU64 << 1;

            const rook_from_rank = to_rank;
            const rook_from_file = to_file + 1;

            const rook_to_rank = from_rank;
            const rook_to_file = from_file + 1;

            const sq_from = rook_from_rank * 8 + rook_from_file;
            const sq_to = rook_to_rank * 8 + rook_to_file;

            self.bitboards[self.to_play.toInt()][team_rook_idx.toInt()] ^= rook_moveU64;
            self.sides[team_color_idx.toInt()] ^= rook_moveU64;
            self.bitboard_idx[sq_to] = self.bitboard_idx[sq_from];
            self.bitboard_idx[sq_from] = .none;


            self.key ^= zobristHash.keys[self.to_play.toInt()][team_rook_idx.toInt()][sq_from];
            self.key ^= zobristHash.keys[self.to_play.toInt()][team_rook_idx.toInt()][sq_to];

            const white: u4 = if (self.isWhiteToPlay()) 0 else 2;

            self.key ^= zobristHash.castling_rights[white] ^ zobristHash.castling_rights[white + 1];
        },
        .queenSideCastle => {
            const team_rook_idx: Piece = .rook;
            const rook_moveU64 = (fromU64 >> 1 | toU64 >> 2);

            const rook_from_rank = to_rank;
            const rook_from_file = to_file - 2;

            const rook_to_rank = from_rank;
            const rook_to_file = from_file - 1;

            const sq_from = rook_from_rank * 8 + rook_from_file;
            const sq_to = rook_to_rank * 8 + rook_to_file;

            self.bitboards[self.to_play.toInt()][team_rook_idx.toInt()] ^= rook_moveU64;
            self.sides[team_color_idx.toInt()] ^= rook_moveU64;
            self.bitboard_idx[sq_to] = self.bitboard_idx[sq_from];
            self.bitboard_idx[sq_from] = .none;

            self.key ^= zobristHash.keys[self.to_play.toInt()][team_rook_idx.toInt()][sq_from];
            self.key ^= zobristHash.keys[self.to_play.toInt()][team_rook_idx.toInt()][sq_to];

            const white: u4 = if (self.isWhiteToPlay()) 0 else 2;

            self.key ^= zobristHash.castling_rights[white] ^ zobristHash.castling_rights[white + 1];
        },
        .knightPromotion, .knightPromotionCapture => {
            const capture = (move.flag().toInt() & 0x4) > 0;

            const target_piece_promotion: Piece = .knight;

            if (capture) {
                self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
                self.sides[enemy_color_idx.toInt()] ^= toU64;
                self.key ^= zobristHash.keys[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()][to];
                self.halfmove_clock = 0;
            }

            self.key ^= zobristHash.keys[self.to_play.toInt()][team_piece_idx.toInt()][to];
            self.key ^= zobristHash.keys[self.to_play.toInt()][target_piece_promotion.toInt()][to];

            self.bitboards[self.to_play.toInt()][target_piece_promotion.toInt()] ^= toU64;
            self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= toU64;
            self.bitboard_idx[to] = target_piece_promotion;
        },
        .bishopPromotion, .bishopPromotionCapture => {
            const capture = (move.flag().toInt() & 0x4) > 0;

            const target_piece_promotion: Piece = .bishop;

            if (capture) {
                self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
                self.sides[enemy_color_idx.toInt()] ^= toU64;
                self.key ^= zobristHash.keys[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()][to];
                self.halfmove_clock = 0;
            }

            self.key ^= zobristHash.keys[self.to_play.toInt()][team_piece_idx.toInt()][to];
            self.key ^= zobristHash.keys[self.to_play.toInt()][target_piece_promotion.toInt()][to];

            self.bitboards[self.to_play.toInt()][target_piece_promotion.toInt()] ^= toU64;
            self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= toU64;
            self.bitboard_idx[to] = target_piece_promotion;
        },
        .rookPromotion, .rookPromotionCapture => {
            const capture = (move.flag().toInt() & 0x4) > 0;

            const target_piece_promotion: Piece = .rook;

            if (capture) {
                self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
                self.sides[enemy_color_idx.toInt()] ^= toU64;
                self.key ^= zobristHash.keys[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()][to];
                self.halfmove_clock = 0;
            }

            self.key ^= zobristHash.keys[self.to_play.toInt()][team_piece_idx.toInt()][to];
            self.key ^= zobristHash.keys[self.to_play.toInt()][target_piece_promotion.toInt()][to];

            self.bitboards[self.to_play.toInt()][target_piece_promotion.toInt()] ^= toU64;
            self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= toU64;
            self.bitboard_idx[to] = target_piece_promotion;
        },
        .queenPromotion, .queenPromotionCapture => {
            const capture = (move.flag().toInt() & 0x4) > 0;

            const target_piece_promotion: Piece = .queen;

            if (capture) {
                self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
                self.sides[enemy_color_idx.toInt()] ^= toU64;
                self.key ^= zobristHash.keys[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()][to];
                self.halfmove_clock = 0;
            }

            self.key ^= zobristHash.keys[self.to_play.toInt()][team_piece_idx.toInt()][to];
            self.key ^= zobristHash.keys[self.to_play.toInt()][target_piece_promotion.toInt()][to];

            self.bitboards[self.to_play.toInt()][target_piece_promotion.toInt()] ^= toU64;
            self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= toU64;
            self.bitboard_idx[to] = target_piece_promotion;
        },
        else => {},
    }

    const sus: u4 = if (self.isWhiteToPlay()) ~@as(u4, 0x3) else ~@as(u4, 0xC);
    self.castle_rights &= if (team_piece_idx == .king) sus else ~@as(u4, 0);

    if (team_piece_idx == .rook and (self.castle_rights & 0x3) > 0 and self.isWhiteToPlay()) {
        const k_rights: u4 = if ((self.castle_rights & 0x1) > 0 and from == 7) ~@as(u4, 0x1) else ~@as(u4, 0);
        const q_rigths = if ((self.castle_rights & 0x2) > 0 and from == 0) ~@as(u4, 0x2) else ~@as(u4, 0);
        self.castle_rights &= k_rights & q_rigths;
        self.key ^= if (@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }else if (team_piece_idx == .rook and (self.castle_rights & 0xC) > 0 and !self.isWhiteToPlay()) {
        const k_rights: u4 = if ((self.castle_rights & 0x4) > 0 and from == 63) ~@as(u4, 0x4) else ~@as(u4, 0);
        const q_rigths = if ((self.castle_rights & 0x8) > 0 and from == 56) ~@as(u4, 0x8) else ~@as(u4, 0);
        self.castle_rights &= k_rights & q_rigths;
        self.key ^= if (@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }

    if (enemy_piece_idx == .rook and (self.castle_rights & 0x3) > 0 and !self.isWhiteToPlay()) {
        const k_rights: u4 = if ((self.castle_rights & 0x1) > 0 and to == 7) ~@as(u4, 0x1) else ~@as(u4, 0);
        const q_rigths = if ((self.castle_rights & 0x2) > 0 and to == 0) ~@as(u4, 0x2) else ~@as(u4, 0);
        self.castle_rights &= k_rights & q_rigths;
        self.key ^= if (@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    } else if (enemy_piece_idx == .rook and (self.castle_rights & 0xC) > 0 and self.isWhiteToPlay()) {
        const k_rights: u4 = if ((self.castle_rights & 0x4) > 0 and to == 63) ~@as(u4, 0x4) else ~@as(u4, 0);
        const q_rigths = if ((self.castle_rights & 0x8) > 0 and to == 56) ~@as(u4, 0x8) else ~@as(u4, 0);
        self.castle_rights &= k_rights & q_rigths;
        self.key ^= if (@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }

    self.ply += 1;
    self.sides[Side.toInt(.both)] = self.sides[team_color_idx.toInt()] | self.sides[enemy_color_idx.toInt()];
  
    self.key ^= zobristHash.side_keys[self.to_play.toInt()];
    self.to_play.change();
    self.key ^= zobristHash.side_keys[self.to_play.toInt()];
}

pub fn unmakeMove2(self: *Self, move: Move) void {
    self.ply -= 1;

    self.to_play.change();

    self.castle_rights = self.position_history[self.ply].castle_rights;
    self.en_passant_sq = self.position_history[self.ply].ep_square;
    self.key = self.position_history[self.ply].key;
    self.halfmove_clock = self.position_history[self.ply].halfmove_clock;
    const capture_piece = self.position_history[self.ply].capture;

    const from = move.from();
    const to = move.to();

    const fromU64 = @as(u64, 1) << from;
    const toU64 = @as(u64, 1) << to;
    const from_toU64 = fromU64 | toU64;

    const from_rank = from >> 3;
    const from_file = from & 7;

    const to_rank = to >> 3;
    const to_file = to & 7;

    const team_piece_idx = self.bitboard_idx[to];
    const team_color_idx: Side = if (self.isWhiteToPlay()) .white else .black;

    const enemy_piece_idx = capture_piece;
    const enemy_color_idx: Side = if (self.isWhiteToPlay()) .black else .white;

    self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= from_toU64;
    self.sides[team_color_idx.toInt()] ^= from_toU64;
    self.bitboard_idx[from] = team_piece_idx;
    self.bitboard_idx[to] = capture_piece;

    switch (move.flag()) {
        .capture => {
            self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
            self.sides[enemy_color_idx.toInt()] ^= toU64;
        },
        .epCapture => {

            var sq: u6 = 0;
            if(self.isWhiteToPlay()){
                sq = to - 8;
            }else{
                sq = to + 8;
            }
            const ep_sqU64 = (@as(u64, 1) << (sq));
            const enemy_pawn_piece_idx = capture_piece;
            self.bitboard_idx[to] = .none;
            self.bitboard_idx[@ctz(ep_sqU64)] = capture_piece;

            self.bitboards[self.to_play.enemy().toInt()][enemy_pawn_piece_idx.toInt()] ^= ep_sqU64;
            self.sides[enemy_color_idx.toInt()] ^= ep_sqU64;
        },
        .kingSideCastle => {
            const team_rook_idx: Piece = .rook;
            const rook_moveU64 = from_toU64 << 1;

            const rook_from_rank = to_rank;
            const rook_from_file = to_file + 1;

            const rook_to_rank = from_rank;
            const rook_to_file = from_file + 1;

            self.bitboards[self.to_play.toInt()][team_rook_idx.toInt()] ^= rook_moveU64;
            self.sides[team_color_idx.toInt()] ^= rook_moveU64;
            self.bitboard_idx[rook_from_rank * 8 + rook_from_file] = self.bitboard_idx[rook_to_rank * 8 + rook_to_file];
            self.bitboard_idx[rook_to_rank * 8 + rook_to_file] = .none;
        },
        .queenSideCastle => {
            const team_rook_idx: Piece = .rook;
            const rook_moveU64 = (fromU64 >> 1 | toU64 >> 2);

            const rook_from_rank = to_rank;
            const rook_from_file = to_file - 2;

            const rook_to_rank = from_rank;
            const rook_to_file = from_file - 1;

            self.bitboards[self.to_play.toInt()][team_rook_idx.toInt()] ^= rook_moveU64;
            self.sides[team_color_idx.toInt()] ^= rook_moveU64;
            self.bitboard_idx[rook_from_rank * 8 + rook_from_file] = self.bitboard_idx[rook_to_rank * 8 + rook_to_file];
            self.bitboard_idx[rook_to_rank * 8 + rook_to_file] = .none;
        },
        else => {},
    }

    if (move.isPromotion()) {
        const pawn_team_idx: Piece = .pawn;

        const capture = (move.flag().toInt() & 0x4) > 0;

        if (capture) {
            self.bitboards[self.to_play.enemy().toInt()][enemy_piece_idx.toInt()] ^= toU64;
            self.sides[enemy_color_idx.toInt()] ^= toU64;
        }

        self.bitboards[self.to_play.toInt()][team_piece_idx.toInt()] ^= fromU64;
        self.bitboards[self.to_play.toInt()][pawn_team_idx.toInt()] ^= fromU64;
        self.bitboard_idx[from] = pawn_team_idx;
    }

    self.sides[Side.toInt(.both)] = self.sides[team_color_idx.toInt()] | self.sides[enemy_color_idx.toInt()];
}

pub fn generateMoves(self: *Self) MoveList {
    //std.debug.print("sq {}\n", .{self.en_passant_sq});
    const team = self.teamPieces();
    const king: u64 = team[5];

    const enemy = self.enemyPieces();

    const teamOcc: u64 = self.teamOccupancy();

    const enemyOcc: u64 = self.enemyOccupancy();

    const occ: u64 = self.notEmpty();

    const kingSquare: u6 = @intCast(@ctz(king));

    const enemyAttacks: u64 = self.getAttackSet(if (self.to_play == .white) .black else .white, occ ^ king);

    const is_king_in_check: bool = (king & enemyAttacks) > 0;

    const kingMoves: u64 = lookup_tables.getKingMoveSet(kingSquare).mask & ~(enemyAttacks | teamOcc);

    const pawnAttacks: u64 = lookup_tables.getPawnAttackSet(kingSquare, self.to_play.toInt()).mask;
    const bishopRays: u64 = lookup_tables.getBishopMoveSet(kingSquare, occ).mask;
    const knight_attacks: u64 = lookup_tables.getKnightMoveSet(kingSquare).mask;
    const rookRays: u64 = lookup_tables.getRookMoveSet(kingSquare, occ).mask;

    const potentialPawnAttackers: u64 = pawnAttacks & enemy[0];
    const potentialBishopAttackers: u64 = bishopRays & (enemy[1] | enemy[4]);
    const potentialKnightAttackers: u64 = knight_attacks & enemy[2];
    const potentialRookAttackers: u64 = rookRays & (enemy[3] | enemy[4]);

    const ghost_rook: u64 = lookup_tables.getRookMask(kingSquare).mask;
    const ghost_bishop: u64 = lookup_tables.getBishopMask(kingSquare).mask;

    var move_list = MoveList.Init();

    if (@popCount(potentialPawnAttackers | potentialBishopAttackers | potentialKnightAttackers | potentialRookAttackers) > 1) {
        storePieceMoves(&move_list, .{
            .legalSquares = kingMoves & ~enemyOcc,
            .legalCaptures = kingMoves & enemyOcc,
            .from = kingSquare,
        });

        return move_list;
    }

    var potential_pinned_pieces: u64 = rookRays & teamOcc;

    var rqAttackers: u64 = ghost_rook & (enemy[4] | enemy[3]);
    var pinnedPiecesMask: u64 = 0;

    while (rqAttackers > 0) : (rqAttackers = bit_set.popLstb(rqAttackers)) {
        pinnedPiecesMask |= lookup_tables.getRookMoveSet(@ctz(rqAttackers), occ).mask & potential_pinned_pieces;
    }

    potential_pinned_pieces = bishopRays & teamOcc;
    var bqAttackers: u64 = ghost_bishop & (enemy[4] | enemy[1]);

    while (bqAttackers > 0) : (bqAttackers = bit_set.popLstb(bqAttackers)) {
        pinnedPiecesMask |= lookup_tables.getBishopMoveSet(@ctz(bqAttackers), occ).mask & potential_pinned_pieces;
    }

    const pawns_not_pinned: u64 = team[0] & ~pinnedPiecesMask;
    const bishops_not_pinned: u64 = team[1] & ~pinnedPiecesMask;
    const knights_not_pinned: u64 = team[2] & ~pinnedPiecesMask;
    const rooks_not_pinned: u64 = team[3] & ~pinnedPiecesMask;
    const queens_not_pinned: u64 = team[4] & ~pinnedPiecesMask;

    const pawns_pinned: u64 = team[0] & pinnedPiecesMask;
    const bishop_pinned: u64 = team[1] & pinnedPiecesMask;
    const rooks_pinned: u64 = team[3] & pinnedPiecesMask;
    const queens_pinned: u64 = team[4] & pinnedPiecesMask;

    var move_set_list: MoveSetList = .{
        .count = 0,
        .from = undefined,
        .moveSets = undefined,
    };

    var bishops: u64 = bishops_not_pinned;
    var knights: u64 = knights_not_pinned;
    var rooks: u64 = rooks_not_pinned;
    var queens: u64 = queens_not_pinned;

    var bishops_p = bishop_pinned & bishopRays;
    var rooks_p = rooks_pinned & rookRays;
    var queens_pb = queens_pinned & bishopRays;
    var queens_pr = queens_pinned & rookRays;

    var mask: u64 = 0;
    var check: bool = false;

    while (bishops > 0) : (bishops = bit_set.popLstb(bishops)) {
        move_set_list.add(lookup_tables.getBishopMoveSet(@ctz(bishops), occ).mask, @intCast(@ctz(bishops)));
    }

    while (knights > 0) : (knights = bit_set.popLstb(knights)) {
        move_set_list.add(lookup_tables.getKnightMoveSet(@ctz(knights)).mask, @intCast(@ctz(knights)));
    }

    while (rooks > 0) : (rooks = bit_set.popLstb(rooks)) {
        move_set_list.add(lookup_tables.getRookMoveSet(@ctz(rooks), occ).mask, @intCast(@ctz(rooks)));
    }

    while (queens > 0) : (queens = bit_set.popLstb(queens)) {
        move_set_list.add(lookup_tables.getQueenMoveSet(@ctz(queens), occ).mask, @intCast(@ctz(queens)));
    }

    if (!is_king_in_check) {
        mask = ~teamOcc;
        
        while (bishops_p > 0) : (bishops_p = bit_set.popLstb(bishops_p)) {
            const bishopMoves: u64 = lookup_tables.getBishopMoveSet(@ctz(bishops_p), occ).mask & ghost_bishop;
            move_set_list.add(bishopMoves, @intCast(@ctz(bishops_p)));
        }

        while (rooks_p > 0) : (rooks_p = bit_set.popLstb(rooks_p)) {
            const rookMoves: u64 = lookup_tables.getRookMoveSet(@ctz(rooks_p), occ).mask & ghost_rook;
            move_set_list.add(rookMoves, @intCast(@ctz(rooks_p)));
        }

        while (queens_pb > 0) : (queens_pb = bit_set.popLstb(queens_pb)) {
            const queen_moves: u64 = lookup_tables.getBishopMoveSet(@ctz(queens_pb), occ).mask & ghost_bishop;
            move_set_list.add(queen_moves, @intCast(@ctz(queens_pb)));
        }

        while (queens_pr > 0) : (queens_pr = bit_set.popLstb(queens_pr)) {
            const queen_moves: u64 = lookup_tables.getRookMoveSet(@ctz(queens_pr), occ).mask & ghost_rook;
            move_set_list.add(queen_moves, @intCast(@ctz(queens_pr)));
        }
    } else {
        check = true;

        if (potentialPawnAttackers != 0 or potentialKnightAttackers != 0) {
            mask = potentialPawnAttackers | potentialKnightAttackers;
        } else if (potentialBishopAttackers != 0) {
            mask = (lookup_tables.getBishopMoveSet(@ctz(potentialBishopAttackers), occ).mask & bishopRays) | potentialBishopAttackers;
        } else if (potentialRookAttackers != 0) {
            mask = (lookup_tables.getRookMoveSet(@ctz(potentialRookAttackers), occ).mask & rookRays) | potentialRookAttackers;
        }
    }

    for (0..move_set_list.count) |i| {
        move_set_list.moveSets[i] &= mask;
    }

    const enPassant = self.getEnPassantSquare(pawns_not_pinned | (pawns_pinned & bishopRays), king);
    //std.debug.print("{}\n", .{enPassant});

    self.generatePawnMoves2(&move_list, pawns_not_pinned, .{
        .legalSquares = mask & ~enemyOcc,
        .legalCaptures = mask & enemyOcc,
        .from = 0,
    }, enPassant);

    if (!check) {
        self.generateKingCastleMoves(&move_list, kingSquare, enemyAttacks, teamOcc, enemyOcc);

        if (pawns_pinned > 0) {
            self.generatePawnMoves2( // the pawns that are behind and in front of the king and are pinned can't capture, this only generate those moves
                &move_list, (pawns_pinned & ~(@as(u64, 0xFF) << ((kingSquare >> 3) * 8))) & ghost_rook, .{
                    .legalSquares = mask & ghost_rook,
                    .legalCaptures = 0,
                    .from = 0,
                }, 0);

            self.generatePawnMoves2( //this generates the pawns that are pinned by a bishop
                &move_list, pawns_pinned & bishopRays, .{
                    .legalSquares = 0,
                    .legalCaptures = ghost_bishop & (enemy[4] | enemy[1]),
                    .from = 0,
                }, enPassant & ghost_bishop);
        }
    }

    for (0..move_set_list.count) |i| {
        if (move_set_list.moveSets[i] == 0) continue;

        const moveset = move_set_list.moveSets[i];

        storePieceMoves(&move_list, .{
            .legalSquares = moveset & ~enemyOcc,
            .legalCaptures = moveset & enemyOcc,
            .from = move_set_list.from[i],
        });
    }

    storePieceMoves(&move_list, .{
        .legalSquares = kingMoves & ~enemyOcc,
        .legalCaptures = kingMoves & enemyOcc,
        .from = @intCast(@ctz(king)),
    });

    return move_list;
}

fn getEnPassantSquare(self: *Self, tPawns: u64, kingSquare: u64) u64 {
    std.debug.assert(kingSquare != 0);
    if (self.en_passant_sq != 0) {

        var enPassantAttackers: u64 = lookup_tables.getPawnAttackSet(self.en_passant_sq, self.to_play.enemy().toInt()).mask & tPawns;
        //std.debug.print("ep attackers 0x{x}\n", .{enPassantAttackers});
        if (@popCount(enPassantAttackers) == 0) {
            return 0;
        }
        

        while (enPassantAttackers > 0) : (enPassantAttackers = bit_set.popLstb(enPassantAttackers)) {
            const move = Move.New(@intCast(@ctz(enPassantAttackers)), self.en_passant_sq, .epCapture);
            const team = self.to_play;
            
            self.makeMove2(move);

            if (!self.isKingInCheck(team, self.notEmpty())) {
            
                self.unmakeMove2(move);
                return @as(u64, 1) << self.en_passant_sq;
            }

            self.unmakeMove2(move);
        }

        return 0;
    }

    return 0;
}

fn generatePawnMoves2(self: *const Self, moveList: *MoveList, bitboard: u64, genInfo: PieceStoreMoveInfo, enPassantSquare: u64) void {
    var normalPush: u64 = 0;
    var doublePush: u64 = 0;
    var promotions: u64 = 0;
    var offset: i6 = 0;
    var attackSet: u64 = 0;
    var captures: u64 = 0;
    var promotionsWithCapture: u64 = 0;
    const e = self.empty();

    if (self.to_play == .white) {
        normalPush = ((bitboard << 8) & e);
        doublePush = ((normalPush & rank3) << 8) & e;

        normalPush &= genInfo.legalSquares;
        doublePush &= genInfo.legalSquares;

        promotions = normalPush & rank8;
        normalPush ^= promotions;
        offset = -8;

        attackSet = (((bitboard << 9) & notAFile) | ((bitboard << 7) & notHFile));
        promotionsWithCapture = attackSet & rank8 & genInfo.legalCaptures;
        attackSet ^= promotionsWithCapture;
    } else {
        normalPush = (bitboard >> 8 & e);
        doublePush = ((normalPush & rank6) >> 8) & e;

        normalPush &= genInfo.legalSquares;
        doublePush &= genInfo.legalSquares;

        promotions = normalPush & rank1;
        normalPush ^= promotions;
        offset = 8;

        attackSet = (((bitboard >> 7) & notAFile) | ((bitboard >> 9) & notHFile));
        promotionsWithCapture = attackSet & rank1 & genInfo.legalCaptures;
        attackSet ^= promotionsWithCapture;
    }

    captures = attackSet & genInfo.legalCaptures;

    while (normalPush > 0) : (normalPush &= normalPush - 1) {
        const sq: u6 = @intCast(@ctz(normalPush));
        moveList.add(Move.New(sq +% @as(u6, @bitCast(offset)), sq, .quietMove));
    }

    while (doublePush > 0) : (doublePush &= doublePush - 1) {
        const sq: u6 = @intCast(@ctz(doublePush));
        moveList.add(Move.New(sq +% @as(u6, @bitCast(offset * 2)), sq, .doublePawnPush));
    }

    while (promotions > 0) : (promotions &= promotions - 1) {
        const sq: u6 = @intCast(@ctz(promotions));
        inline for (0..4) |i| {
            moveList.add(Move.New(sq +% @as(u6, @bitCast(offset)), sq, @fromBackingInt(@intCast(Move.Flags.toInt(.knightPromotion) + @as(u4, @intCast(i))))));
        }
    }

    while (captures > 0) : (captures = bit_set.popLstb(captures)) {
        const sq: u6 = @intCast(@ctz(captures));
        var attackers: u64 = lookup_tables.getPawnAttackSet(sq, self.to_play.enemy().toInt()).mask & bitboard;
        while (attackers > 0) : (attackers = bit_set.popLstb(attackers)) {
            moveList.add(Move.New(@intCast(@ctz(attackers)), sq, .capture));
        }
    }

    if ((attackSet & enPassantSquare) > 0) {
        const sq: u6 = self.en_passant_sq;
        var attackers: u64 = lookup_tables.getPawnAttackSet(sq, self.to_play.enemy().toInt()).mask & bitboard;
        while (attackers > 0) : (attackers = bit_set.popLstb(attackers)) {
            moveList.add(Move.New(@intCast(@ctz(attackers)), sq, .epCapture));
        }
    }

    while (promotionsWithCapture > 0) : (promotionsWithCapture = bit_set.popLstb(promotionsWithCapture)) {
        const sq: u6 = @intCast(@ctz(promotionsWithCapture));
        var attackers: u64 = lookup_tables.getPawnAttackSet(sq, self.to_play.enemy().toInt()).mask & bitboard;
        while (attackers > 0) : (attackers = bit_set.popLstb(attackers)) {
            inline for (0..4) |i| {
                moveList.add(Move.New(@intCast(@ctz(attackers)), sq, @fromBackingInt(@intCast(Move.Flags.toInt(.knightPromotionCapture) + @as(u4, @intCast(i))))));
            }
        }
    }
}

fn generateKingCastleMoves(self: *const Self, moveList: *MoveList, kingSquare: u6, enemyAttackSet: u64, team: u64, enemy: u64) void {
    const queenSideCastleMask: u64 = @as(u64, 0xc) << ((kingSquare >> 3) << 3);
    const kingSideCastleMask: u64 = @as(u64, 0x60) << ((kingSquare >> 3) << 3);
    const queenSideCastleMaskB: u64 = (queenSideCastleMask >> @as(u6, 1)) | queenSideCastleMask;

    const castleRights: u2 = @intCast((self.castle_rights >> (@as(u2, @intFromBool(self.to_play == .black)) << 1)) & 0x3);

    const kingSideCastle: bool = (castleRights & 0x1) > 0 and (kingSideCastleMask & (enemyAttackSet | team | enemy)) == 0;
    const queenSideCastle: bool = (castleRights & 0x2) > 0 and (queenSideCastleMask & enemyAttackSet) == 0 and queenSideCastleMaskB & (team | enemy) == 0;

    if (kingSideCastle) {
        moveList.add(Move.New(kingSquare, kingSquare + 2, .kingSideCastle));
    }

    if (queenSideCastle) {
        moveList.add(Move.New(kingSquare, kingSquare - 2, .queenSideCastle));
    }
}

fn getAttackSet(self: *const Self, color: Side, occ: u64) u64 {
    var attackSet: u64 = 0;

    const attackers = self.pieces(color);

    var pawnAttacks: u64 = 0;

    if (color == .white) {
        pawnAttacks = (attackers[0] << 9 & notAFile) | (attackers[0] << 7 & notHFile);
    } else {
        pawnAttacks = (attackers[0] >> 7 & notAFile) | (attackers[0] >> 9 & notHFile);
    }

    attackSet |= pawnAttacks;
    attackSet |= lookup_tables.getKingMoveSet(@intCast(@ctz(attackers[5]))).mask;

    var bishops: u64 = attackers[1];
    while (bishops > 0) : (bishops &= bishops - 1) {
        attackSet |= lookup_tables.getBishopMoveSet(@intCast(@ctz(bishops)), occ).mask;
    }

    var knights: u64 = attackers[2];
    while (knights > 0) : (knights &= knights - 1) {
        attackSet |= lookup_tables.getKnightMoveSet(@intCast(@ctz(knights))).mask;
    }

    var rooks: u64 = attackers[3];
    while (rooks > 0) : (rooks &= rooks - 1) {
        attackSet |= lookup_tables.getRookMoveSet(@intCast(@ctz(rooks)), occ).mask;
    }

    var queens: u64 = attackers[4];
    while (queens > 0) : (queens &= queens - 1) {
        attackSet |= lookup_tables.getQueenMoveSet(@intCast(@ctz(queens)), occ).mask;
    }

    return attackSet;
}

fn getSquareAttackers(self: *const Self, square: u6, side: Side, occ: u64) u64 {
    const attackers = self.pieces(side);

    const rqattackers: u64 = lookup_tables.getRookMoveSet(square, occ).mask & (attackers[3] | attackers[4]);
    const bqattackers: u64 = lookup_tables.getBishopMoveSet(square, occ).mask & (attackers[1] | attackers[4]);
    const pattackers: u64 = lookup_tables.getPawnAttackSet(square, side.enemy().toInt()).mask & attackers[0];
    const nattackers: u64 = lookup_tables.getKnightMoveSet(square).mask & attackers[2];
    const kattackers: u64 = lookup_tables.getKingMoveSet(square).mask & attackers[5];

    return rqattackers | bqattackers | pattackers | nattackers | kattackers;
}

fn isSquareAttacked(self: *const Self, square: u6, side: Side, occ: u64) bool {
    return self.getSquareAttackers(square, side, occ) > 0;
}

pub fn isKingInCheck(self: *const Self, side: Side, occ: u64) bool {
    return self.isSquareAttacked(@intCast(@ctz(self.pieceSet(side, .king))), side.enemy(), occ);
}

pub inline fn isWhiteToPlay(self: *const Self) bool {
    return self.to_play == .white;
}

pub inline fn isBlackToPlay(self: *const Self) bool {
    return self.to_play == .black;
}

fn storePieceMoves(move_list: *MoveList, piece_info: PieceStoreMoveInfo) void {
    var moves: u64 = piece_info.legalSquares;
    var captures: u64 = piece_info.legalCaptures;

    while (moves > 0) : (moves = bit_set.popLstb(moves)) {
        move_list.add(Move.New(piece_info.from, @intCast(@ctz(moves)), .quietMove));
    }

    while (captures > 0) : (captures = bit_set.popLstb(captures)) {
        move_list.add(Move.New(
            piece_info.from,
            @intCast(@ctz(captures)),
            .capture,
        ));
    }
}
