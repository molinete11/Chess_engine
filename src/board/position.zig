const std = @import("std");
const bit_set = @import("bitSet.zig");
const lot = @import("lot.zig");
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

pub inline fn init() Self {
    var board = std.mem.zeroes(Self);

    board.setPos(default_fen) catch unreachable;

    return board;
}

pub inline fn setPos(self: *Self, fen: []const u8) !void {
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

pub inline fn restartPos(self: *Self) void {
    self.setPos(default_fen) catch unreachable;
}

pub inline fn getFen(self: *const Self) [92]u8 {
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


pub inline fn makeMove2(self: *Self, move: Move) void {
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

pub inline fn unmakeMove2(self: *Self, move: Move) void {
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

pub inline fn getAttackSet(self: *const Self, color: Side, occ: u64) u64 {
    var attackSet: u64 = 0;

    const attackers = self.pieces(color);

    var pawnAttacks: u64 = 0;

    const not_a_file: u64 = 0xfefefefefefefefe;
    const not_h_file: u64 = 0x7f7f7f7f7f7f7f7f;

    if (color == .white) {
        pawnAttacks = (attackers[0] << 9 & not_a_file) | (attackers[0] << 7 & not_h_file);
    } else {
        pawnAttacks = (attackers[0] >> 7 & not_a_file) | (attackers[0] >> 9 & not_h_file);
    }

    attackSet |= pawnAttacks;
    attackSet |= lot.getKingMoveSet(@intCast(@ctz(attackers[5]))).mask;

    var bishops: u64 = attackers[1];
    while (bishops > 0) : (bishops &= bishops - 1) {
        attackSet |= lot.getBishopMoveSet(@intCast(@ctz(bishops)), occ).mask;
    }

    var knights: u64 = attackers[2];
    while (knights > 0) : (knights &= knights - 1) {
        attackSet |= lot.getKnightMoveSet(@intCast(@ctz(knights))).mask;
    }

    var rooks: u64 = attackers[3];
    while (rooks > 0) : (rooks &= rooks - 1) {
        attackSet |= lot.getRookMoveSet(@intCast(@ctz(rooks)), occ).mask;
    }

    var queens: u64 = attackers[4];
    while (queens > 0) : (queens &= queens - 1) {
        attackSet |= lot.getQueenMoveSet(@intCast(@ctz(queens)), occ).mask;
    }

    return attackSet;
}

pub inline fn getSquareAttackers(self: *const Self, square: u6, side: Side, occ: u64) u64 {
    const attackers = self.pieces(side);

    const rqattackers: u64 = lot.getRookMoveSet(square, occ).mask & (attackers[3] | attackers[4]);
    const bqattackers: u64 = lot.getBishopMoveSet(square, occ).mask & (attackers[1] | attackers[4]);
    const pattackers: u64 = lot.getPawnAttackSet(square, side.enemy().toInt()).mask & attackers[0];
    const nattackers: u64 = lot.getKnightMoveSet(square).mask & attackers[2];
    const kattackers: u64 = lot.getKingMoveSet(square).mask & attackers[5];

    return rqattackers | bqattackers | pattackers | nattackers | kattackers;
}

pub inline fn isSquareAttacked(self: *const Self, square: u6, side: Side, occ: u64) bool {
    return self.getSquareAttackers(square, side, occ) > 0;
}

pub inline fn isKingInCheck(self: *const Self, side: Side, occ: u64) bool {
    return self.isSquareAttacked(@intCast(@ctz(self.pieceSet(side, .king))), side.enemy(), occ);
}

pub inline fn isWhiteToPlay(self: *const Self) bool {
    return self.to_play == .white;
}

pub inline fn isBlackToPlay(self: *const Self) bool {
    return self.to_play == .black;
}