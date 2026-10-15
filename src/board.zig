const std = @import("std");
const lookup_tables = @import("lot.zig");
const bit_set = @import("bitSet.zig");
const Move = @import("move.zig");
const MoveList = @import("moveList.zig");
const zobristHash = @import("zobristHash.zig");

const Self = @This();

pub const Side = enum(u1) {
    white,
    black,

    pub fn change(self: @This()) @This(){
        return if(self == .white) .black else .white;
    }

    pub fn toInt(self: @This()) u1{
        return @backingInt(self);
    }

    pub fn enemy(self: @This()) @This(){
        return @fromBackingInt(self.toInt() ^ 1);
    }
};

pub const PieceBitboardIdx = enum(u4) {
    wPawn,
    wBishop,
    wKnight,
    wRook,
    wQueen,
    wKing,
    bPawn,
    bBishop,
    bKnight,
    bRook,
    bQueen,
    bKing,
    white,
    black,
    all,

    pub inline fn toInt(self: @This()) u4{
        return @intFromEnum(self);
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

    pub fn add(self: *@This(), moveSet: u64, from: u6) void{
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
    capture: u4,
};

const State = enum {
    ongoin,
    checkmate,
    draw
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

bitboards: [15]u64,

bitboard_idx: [8][8]u4,

empty: u64, 

key: u64,

ply: u16,

halfmove_clock: u32,

move_number: u16,

en_passant_sq: u6,

castle_rights: u4,  // bit 1 = K, bit 2 = Q, bit 3 = k, bit 4 = q

to_play: Side,


pub fn init() Self{

    var board = std.mem.zeroes(Self);

    board.setPos(default_fen) catch unreachable;

    return board; 
}

pub fn setPos(self: *Self, fen: []const u8) !void{
    self.clearBoard();
    
    var fenTokens = std.mem.splitAny(u8, fen, " ");

    const fenBoard = fenTokens.first();

    var rank: u8 = 7;
    var file: u8 = 0;

    for(0..fenBoard.len) |i|{

        if(fenBoard[i] == '/'){
            rank -= 1;
            file = 0;
            continue;
        }else if(std.ascii.isDigit(fenBoard[i])){
            if(fenBoard[i] == '9' or fenBoard[i] == '0'){
                return FenError.InvalidFen;
            }
            file += fenBoard[i] & 0xF;
            continue;
        }
        const sq: u64 =  @as(u64, 1) << @intCast(rank * 8 + file);
        
        var bb: u4 = 15;

        switch (fenBoard[i]) {
            'p' => {bb = @intFromEnum(PieceBitboardIdx.bPawn);},
            'b' => {bb = @intFromEnum(PieceBitboardIdx.bBishop);},
            'n' => {bb = @intFromEnum(PieceBitboardIdx.bKnight);},
            'r' => {bb = @intFromEnum(PieceBitboardIdx.bRook);},
            'q' => {bb = @intFromEnum(PieceBitboardIdx.bQueen);}, 'k' => {bb = @intFromEnum(PieceBitboardIdx.bKing);},

            'P' => {bb = @intFromEnum(PieceBitboardIdx.wPawn);},
            'B' => {bb = @intFromEnum(PieceBitboardIdx.wBishop);}, 'N' => {bb = @intFromEnum(PieceBitboardIdx.wKnight);},
            'R' => {bb = @intFromEnum(PieceBitboardIdx.wRook);},
            'Q' => {bb = @intFromEnum(PieceBitboardIdx.wQueen);},
            'K' => {bb = @intFromEnum(PieceBitboardIdx.wKing);},
            else => {return FenError.InvalidFen;},
        }

        self.bitboards[bb] ^= sq;
        self.bitboard_idx[rank][file] = bb;
        self.key ^= zobristHash.keys[bb][@ctz(sq)];

        if(bb >= 6){
            self.bitboards[@intFromEnum(PieceBitboardIdx.black)] ^= sq;
        }else{
            self.bitboards[@intFromEnum(PieceBitboardIdx.white)] ^= sq;
        }

        self.bitboards[@intFromEnum(PieceBitboardIdx.all)] ^= sq;

        file += 1;
    }

    self.empty = ~self.bitboards[@intFromEnum(PieceBitboardIdx.all)];


    const whiteToPlay = fenTokens.next().?;

    if(std.mem.eql(u8, whiteToPlay, "w")){
        self.to_play = .white;
        self.key ^= zobristHash.side_keys[0];
    }else if(std.mem.eql(u8, whiteToPlay, "b")){
        self.to_play = .black;
        self.key ^= zobristHash.side_keys[1];
    }else{
        return FenError.InvalidFen;
    }

    const castleRights = fenTokens.next().?;

    for(0..castleRights.len) |i|{
        switch (castleRights[i]) {
            'K' => {self.castle_rights ^= 0x1; self.key ^= zobristHash.castling_rights[0];},
            'Q' => {self.castle_rights ^= 0x2; self.key ^= zobristHash.castling_rights[1];},
            'k' => {self.castle_rights ^= 0x4; self.key ^= zobristHash.castling_rights[2];},
            'q' => {self.castle_rights ^= 0x8; self.key ^= zobristHash.castling_rights[3];},
            else => {},
        }
    }

    const enPassantSquare = fenTokens.next().?;

    if(!std.mem.eql(u8, enPassantSquare, "-")){
        const fileFrom: u10 = enPassantSquare[0] - 'a';
        const rankFrom: u10 = enPassantSquare[1] - '1';
        const sq: u10 = rankFrom * 8 + fileFrom;

        self.key ^= zobristHash.ep_file[fileFrom];

        if(!(rankFrom == 7 or rankFrom == 3)){
            return FenError.InvalidFen;
        }

        self.en_passant_sq = @intCast(sq);

    }
}

pub fn restartPos(self: *Self) void{
    self.setPos(default_fen) catch unreachable;
}

pub fn getFen(self: *Self) [92]u8{
    _ = self;

    const fen: [92]u8 = @splat(0);

    return fen;
}

inline fn clearBoard(self: *Self) void{
    self.bitboards = @splat(0);
    for(0..8)|i|{
        for(0..8)|j|{
            self.bitboard_idx[i][j] = 15;
        }
    }
    self.castle_rights = 0;
    self.empty = 0;
    self.en_passant_sq = 0;
    self.ply = 0;
    self.key = 0;
    self.to_play = .white;
}



pub fn isThreefoldRepetition(self: *Self) bool{

    var n: u32 = 1;
    
    if(self.halfmove_clock < 4){
        return false;
    }

// en caso de pasar por fen el reloj de halfmove puede estar avanzado por ello esto self.position_history[self.ply - i]; puede dar subflow
// para evitarlo se escoge el menor entre self.halfmove_clock y self.ply
    const halfmove_clock: u32 = @min(self.halfmove_clock, self.ply); 

    var i: u32 = 2;
    //std.debug.print("{}\n", .{self.key});

    while(i <= halfmove_clock): (i += 2){

        const undo = self.position_history[self.ply - i];

        if(undo.key == self.key){
            n += 1;
        }
    
        if(n >= 3){
            return true;
        }
    }

    return false;
}

pub fn isFiftyMoveRule(self: *Self) bool{
    return self.halfmove_clock >= 100;
}

pub fn makeMove2(self: *Self, move: Move) bool{

    const from = move.from();
    const to = move.to();

    const fromU64 = @as(u64, 1) << from;
    const toU64 = @as(u64, 1) << to;
    const from_toU64 = fromU64 | toU64;
    
    const from_rank = from >> 3;
    const from_file = from & 7;

    const to_rank = to >> 3;
    const to_file = to & 7;

    const team_piece_idx = self.bitboard_idx[from_rank][from_file];
    const team_color_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .white else .black;

    const enemy_piece_idx = self.bitboard_idx[to_rank][to_file];
    const enemy_color_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .black else .white;

    self.position_history[self.ply].key = self.key;
    self.position_history[self.ply].ep_square = self.en_passant_sq;
    self.position_history[self.ply].castle_rights = self.castle_rights;
    self.position_history[self.ply].capture = enemy_piece_idx;
    self.position_history[self.ply].halfmove_clock = self.halfmove_clock;

    self.bitboards[team_piece_idx] ^= from_toU64;
    self.bitboards[team_color_idx.toInt()] ^= from_toU64;
    self.bitboard_idx[to_rank][to_file] = team_piece_idx;
    self.bitboard_idx[from_rank][from_file] = 15;
    if(self.en_passant_sq != 0){
        self.key ^= zobristHash.ep_file[self.en_passant_sq & 7];
    }
    self.en_passant_sq = 0;

    self.key ^= zobristHash.keys[team_piece_idx][from];
    self.key ^= zobristHash.keys[team_piece_idx][to];

    self.halfmove_clock += 1;

    self.halfmove_clock = if(team_piece_idx == 0 or team_piece_idx == 6) 0 else self.halfmove_clock;

    switch (move.flag()) {
            .capture => {
                //self.position_history[self.ply].capture = enemy_piece_idx;
                self.bitboards[enemy_piece_idx] ^= toU64;
                self.bitboards[enemy_color_idx.toInt()] ^= toU64;
                self.key ^= zobristHash.keys[enemy_piece_idx][to];
                self.halfmove_clock = 0;
            },
            .doublePawnPush => {
                const offset: i6 = if(self.isWhiteToPlay()) -8 else 8;
                self.en_passant_sq = (to +% @as(u6, @bitCast(offset)));
                self.key ^= zobristHash.ep_file[self.en_passant_sq & 7];
            },
            .epCapture => {
                const offset: i6 = if(self.isWhiteToPlay()) -8 else 8;
                const ep_sqU64 = (@as(u64, 1) << (to +% @as(u6, @bitCast(offset))));
                const enemy_pawn_piece_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .bPawn else .wPawn;
                self.bitboard_idx[from_rank][to_file] = 15;
                self.key ^= zobristHash.keys[enemy_pawn_piece_idx.toInt()][@ctz(ep_sqU64)];
                self.halfmove_clock = 0;

                self.position_history[self.ply].capture = enemy_pawn_piece_idx.toInt();

                self.bitboards[enemy_pawn_piece_idx.toInt()] ^= ep_sqU64;
                self.bitboards[enemy_color_idx.toInt()] ^= ep_sqU64;
            },
            .kingSideCastle => {
                const team_rook_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .wRook else .bRook;
                const rook_moveU64 = from_toU64 << 1;

                const rook_from_rank = to_rank;
                const rook_from_file = to_file + 1;

                const rook_to_rank = from_rank;
                const rook_to_file = from_file + 1;

                self.bitboards[team_rook_idx.toInt()] ^= rook_moveU64;
                self.bitboards[team_color_idx.toInt()] ^= rook_moveU64;
                self.bitboard_idx[rook_to_rank][rook_to_file] = self.bitboard_idx[rook_from_rank][rook_from_file];
                self.bitboard_idx[rook_from_rank][rook_from_file] = 15;

                const sq_from = rook_from_rank * 8 + rook_from_file;
                const sq_to = rook_to_rank * 8 + rook_to_file;

                self.key ^= zobristHash.keys[team_rook_idx.toInt()][sq_from];
                self.key ^= zobristHash.keys[team_rook_idx.toInt()][sq_to];    

                const white: u4 = if(self.isWhiteToPlay()) 0 else 2;

                self.key ^= zobristHash.castling_rights[white] ^ zobristHash.castling_rights[white + 1];
            },
            .queenSideCastle => {
                const team_rook_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .wRook else .bRook;
                const rook_moveU64 = (fromU64 >> 1 | toU64 >> 2);

                const rook_from_rank = to_rank;
                const rook_from_file = to_file - 2;

                const rook_to_rank = from_rank;
                const rook_to_file = from_file - 1;
                
                self.bitboards[team_rook_idx.toInt()] ^= rook_moveU64;
                self.bitboards[team_color_idx.toInt()] ^= rook_moveU64;
                self.bitboard_idx[rook_to_rank][rook_to_file] = self.bitboard_idx[rook_from_rank][rook_from_file];
                self.bitboard_idx[rook_from_rank][rook_from_file] = 15;

                const sq_from = rook_from_rank * 8 + rook_from_file;
                const sq_to = rook_to_rank * 8 + rook_to_file;

                self.key ^= zobristHash.keys[team_rook_idx.toInt()][sq_from];
                self.key ^= zobristHash.keys[team_rook_idx.toInt()][sq_to];

                const white: u4 = if(self.isWhiteToPlay()) 0 else 2;

                self.key ^= zobristHash.castling_rights[white] ^ zobristHash.castling_rights[white + 1];  
            },
            .knightPromotion, .knightPromotionCapture => {
                const capture = (move.flag().toInt() & 0x4) > 0;

                const target_piece_promotion: PieceBitboardIdx = if(self.isWhiteToPlay()) .wKnight else .bKnight;

                if(capture){
                    self.bitboards[enemy_piece_idx] ^= toU64;
                    self.bitboards[enemy_color_idx.toInt()] ^= toU64;
                    self.key ^= zobristHash.keys[enemy_piece_idx][to];
                    self.halfmove_clock = 0;
                }

                self.key ^= zobristHash.keys[team_piece_idx][to];
                self.key ^= zobristHash.keys[target_piece_promotion.toInt()][to];

                self.bitboards[target_piece_promotion.toInt()] ^= toU64;
                self.bitboards[team_piece_idx] ^= toU64;
                self.bitboard_idx[to_rank][to_file] = target_piece_promotion.toInt();
            },
            .bishopPromotion, .bishopPromotionCapture => {
                const capture = (move.flag().toInt() & 0x4) > 0;

                const target_piece_promotion: PieceBitboardIdx = if(self.isWhiteToPlay()) .wBishop else .bBishop;

                if(capture){
                    self.bitboards[enemy_piece_idx] ^= toU64;
                    self.bitboards[enemy_color_idx.toInt()] ^= toU64;
                    self.key ^= zobristHash.keys[enemy_piece_idx][to];
                    self.halfmove_clock = 0;
                }

                self.key ^= zobristHash.keys[team_piece_idx][to];
                self.key ^= zobristHash.keys[target_piece_promotion.toInt()][to];

                self.bitboards[target_piece_promotion.toInt()] ^= toU64;
                self.bitboards[team_piece_idx] ^= toU64;
                self.bitboard_idx[to_rank][to_file] = target_piece_promotion.toInt();
            },
            .rookPromotion, .rookPromotionCapture => {
                const capture = (move.flag().toInt() & 0x4) > 0;

                const target_piece_promotion: PieceBitboardIdx = if(self.isWhiteToPlay()) .wRook else .bRook;

                if(capture){
                    self.bitboards[enemy_piece_idx] ^= toU64;
                    self.bitboards[enemy_color_idx.toInt()] ^= toU64;
                    self.key ^= zobristHash.keys[enemy_piece_idx][to];
                    self.halfmove_clock = 0;
                }

                self.key ^= zobristHash.keys[team_piece_idx][to];
                self.key ^= zobristHash.keys[target_piece_promotion.toInt()][to];

                self.bitboards[target_piece_promotion.toInt()] ^= toU64;
                self.bitboards[team_piece_idx] ^= toU64;
                self.bitboard_idx[to_rank][to_file] = target_piece_promotion.toInt();        
            },
            .queenPromotion, .queenPromotionCapture => {
                const capture = (move.flag().toInt() & 0x4) > 0;

                const target_piece_promotion: PieceBitboardIdx = if(self.isWhiteToPlay()) .wQueen else .bQueen;

                if(capture){
                    self.bitboards[enemy_piece_idx] ^= toU64;
                    self.bitboards[enemy_color_idx.toInt()] ^= toU64;
                    self.key ^= zobristHash.keys[enemy_piece_idx][to];
                    self.halfmove_clock = 0;
                }

                self.key ^= zobristHash.keys[team_piece_idx][to];
                self.key ^= zobristHash.keys[target_piece_promotion.toInt()][to];

                self.bitboards[target_piece_promotion.toInt()] ^= toU64;
                self.bitboards[team_piece_idx] ^= toU64;
                self.bitboard_idx[to_rank][to_file] = target_piece_promotion.toInt();
            },                                      
            else => {},
    }

    const sus: u4 = if(self.isWhiteToPlay()) ~@as(u4, 0x3) else ~@as(u4, 0xC);
    self.castle_rights &= if(team_piece_idx == PieceBitboardIdx.toInt(.wKing) or team_piece_idx == PieceBitboardIdx.toInt(.bKing)) sus else ~@as(u4, 0);

    if((self.castle_rights & 0x3) > 0 and team_piece_idx == PieceBitboardIdx.toInt(.wRook)){
            const k_rights: u4 = if((self.castle_rights & 0x1) > 0 and from == 7) ~@as(u4, 0x1) else ~@as(u4, 0);
            const q_rigths = if((self.castle_rights & 0x2) > 0 and from == 0) ~@as(u4, 0x2) else ~@as(u4, 0);
            self.castle_rights &= k_rights & q_rigths;
            self.key ^= if(@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }else if((self.castle_rights & 0xC) > 0 and team_piece_idx == PieceBitboardIdx.toInt(.bRook)){
            const k_rights: u4 = if((self.castle_rights & 0x4) > 0 and from == 63) ~@as(u4, 0x4) else ~@as(u4, 0);
            const q_rigths = if((self.castle_rights & 0x8) > 0 and from == 56) ~@as(u4, 0x8) else ~@as(u4, 0);
            self.castle_rights &= k_rights & q_rigths;
            self.key ^= if(@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }

    if((self.castle_rights & 0x3) > 0 and enemy_piece_idx == PieceBitboardIdx.toInt(.wRook)){
            const k_rights: u4 = if((self.castle_rights & 0x1) > 0 and to == 7) ~@as(u4, 0x1) else ~@as(u4, 0);
            const q_rigths = if((self.castle_rights & 0x2) > 0 and to == 0) ~@as(u4, 0x2) else ~@as(u4, 0);
            self.castle_rights &= k_rights & q_rigths;
            self.key ^=  if(@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }else if((self.castle_rights & 0xC) > 0 and enemy_piece_idx == PieceBitboardIdx.toInt(.bRook)){
            const k_rights: u4 = if((self.castle_rights & 0x4) > 0 and to == 63) ~@as(u4, 0x4) else ~@as(u4, 0);
            const q_rigths = if((self.castle_rights & 0x8) > 0 and to == 56) ~@as(u4, 0x8) else ~@as(u4, 0);
            self.castle_rights &= k_rights & q_rigths;
            self.key ^= if(@ctz(~(k_rights & q_rigths)) < 4) zobristHash.castling_rights[@ctz(~(k_rights & q_rigths))] else 0;
    }

    self.ply += 1;
    self.bitboards[PieceBitboardIdx.toInt(.all)] = self.bitboards[team_color_idx.toInt()] | self.bitboards[enemy_color_idx.toInt()];
    self.empty = ~self.bitboards[PieceBitboardIdx.toInt(.all)];

    self.key ^= zobristHash.side_keys[@intFromEnum(self.to_play)];
    self.to_play = self.to_play.change();
    self.key ^= zobristHash.side_keys[@intFromEnum(self.to_play)];

    if(self.isKingInCheck(self.to_play.enemy(), self.bitboards[PieceBitboardIdx.toInt(.all)])){
        self.unmakeMove2(move);
        return false;
    }
    return true;
}   

pub fn unmakeMove2(self: *Self, move: Move) void{
    self.ply -= 1;

    self.to_play = self.to_play.change();

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

    const team_piece_idx = self.bitboard_idx[to_rank][to_file];
    const team_color_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .white else .black;

    const enemy_piece_idx = capture_piece;
    const enemy_color_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .black else .white;

    self.bitboards[team_piece_idx] ^= from_toU64;
    self.bitboards[team_color_idx.toInt()] ^= from_toU64;
    self.bitboard_idx[from_rank][from_file] = team_piece_idx;
    self.bitboard_idx[to_rank][to_file] = capture_piece;

    switch (move.flag()) {
        .capture => {
            self.bitboards[enemy_piece_idx] ^= toU64;
            self.bitboards[enemy_color_idx.toInt()] ^= toU64;
        },
        .epCapture => {
            const offset: i6 = if(self.isWhiteToPlay()) -8 else 8;
            const ep_sqU64 = (@as(u64, 1) << (to +% @as(u6, @bitCast(offset))));
            const enemy_pawn_piece_idx = capture_piece;
            self.bitboard_idx[from_rank][to_file] = capture_piece;

            self.bitboards[enemy_pawn_piece_idx] ^= ep_sqU64;
            self.bitboards[enemy_color_idx.toInt()] ^= ep_sqU64;
        },
        .kingSideCastle => {
            const team_rook_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .wRook else .bRook;
            const rook_moveU64 = from_toU64 << 1;

            const rook_from_rank = to_rank;
            const rook_from_file = to_file + 1;

            const rook_to_rank = from_rank;
            const rook_to_file = from_file + 1;

            self.bitboards[team_rook_idx.toInt()] ^= rook_moveU64;
            self.bitboards[team_color_idx.toInt()] ^= rook_moveU64;
            self.bitboard_idx[rook_from_rank][rook_from_file] = self.bitboard_idx[rook_to_rank][rook_to_file];
            self.bitboard_idx[rook_to_rank][rook_to_file] = 15;   
        },
        .queenSideCastle => {
            const team_rook_idx: PieceBitboardIdx = if(self.isWhiteToPlay()) .wRook else .bRook;
            const rook_moveU64 = (fromU64 >> 1 | toU64 >> 2);

            const rook_from_rank = to_rank;
            const rook_from_file = to_file - 2;

            const rook_to_rank = from_rank;
            const rook_to_file = from_file - 1;

            self.bitboards[team_rook_idx.toInt()] ^= rook_moveU64;
            self.bitboards[team_color_idx.toInt()] ^= rook_moveU64;
            self.bitboard_idx[rook_from_rank][rook_from_file] = self.bitboard_idx[rook_to_rank][rook_to_file];
            self.bitboard_idx[rook_to_rank][rook_to_file] = 15;   
        },
        else => {}
    }

   if(move.isPromotion()) {
        const pawn_team_idx = if(self.isWhiteToPlay()) PieceBitboardIdx.wPawn else PieceBitboardIdx.bPawn;

        const capture = (move.flag().toInt() & 0x4) > 0;

        if(capture){
            self.bitboards[enemy_piece_idx] ^= toU64;
            self.bitboards[enemy_color_idx.toInt()] ^= toU64;
        }

        self.bitboards[team_piece_idx] ^= fromU64;
        self.bitboards[pawn_team_idx.toInt()] ^= fromU64;
        self.bitboard_idx[from_rank][from_file] = pawn_team_idx.toInt();
    }

    self.bitboards[PieceBitboardIdx.toInt(.all)] = self.bitboards[team_color_idx.toInt()] | self.bitboards[enemy_color_idx.toInt()];
    self.empty = ~self.bitboards[PieceBitboardIdx.toInt(.all)];
}

pub fn generateMoves(self: *Self) MoveList{
    const blackToPlay: u4 = @bitCast(-@as(i4, @intFromBool(self.isBlackToPlay())));
    const startPieceTeamIdx: u4 = (6 & blackToPlay);
    const endPieceTeamIdx: u4 = 6 + (6 & blackToPlay);
    const startPieceEnemyIdx: u4 = 6 & ~blackToPlay;
    const endPieceEnemyIdx: u4 = 6 + (6 & ~blackToPlay);

    const pieces: []u64 = self.bitboards[startPieceTeamIdx..endPieceTeamIdx];
    const king: u64 = pieces[5];

    const enemyPieces: []u64 = self.bitboards[startPieceEnemyIdx..endPieceEnemyIdx];

    const teamOccIdx = (@intFromEnum(PieceBitboardIdx.white) & ~blackToPlay) | (@intFromEnum(PieceBitboardIdx.black) & blackToPlay);
    const enemyOccIdx = (@intFromEnum(PieceBitboardIdx.white) & blackToPlay) | (@intFromEnum(PieceBitboardIdx.black) & ~blackToPlay);

    const team: u64 = self.bitboards[teamOccIdx];

    const enemy: u64 = self.bitboards[enemyOccIdx];

    const occ: u64 = team | enemy;

    const kingSquare: u6 = @intCast(@ctz(king));

    const enemyAttacks: u64 = self.getAttackSet(if(self.to_play == .white) Side.black else Side.white, occ ^ pieces[5]);
  
    const kingMoves: u64 = lookup_tables.getKingMoveSet(kingSquare).mask & ~(enemyAttacks | team);

    const pawnAttacks: u64 = lookup_tables.getPawnAttackSet(kingSquare, @intFromEnum(self.to_play)).mask;
    const bishopRays: u64 = lookup_tables.getBishopMoveSet(kingSquare, occ).mask;
    const kgniht_attacks: u64 = lookup_tables.getKnightMoveSet(kingSquare).mask;
    const rookRays: u64 = lookup_tables.getRookMoveSet(kingSquare, occ).mask;

    const potentialPawnAttackers: u64 = pawnAttacks & enemyPieces[0];
    const potentialBishopAttackers: u64 = bishopRays & (enemyPieces[1] | enemyPieces[4]);
    const potentialKnightAttackers: u64 = kgniht_attacks & enemyPieces[2];
    const potentialRookAttackers: u64 = rookRays & (enemyPieces[3] | enemyPieces[4]);

    var move_list = MoveList.Init();

    if(@popCount(potentialPawnAttackers | potentialBishopAttackers | potentialKnightAttackers | potentialRookAttackers) > 1){

        storePieceMoves(
            &move_list,
            .{
            .legalSquares = kingMoves & ~enemy,
            .legalCaptures = kingMoves & enemy,
            .from = kingSquare,
        });

        return move_list;
    }

    var move_set_list: MoveSetList = .{
        .count = 0,
        .from = undefined,
        .moveSets = undefined,
    };

    const pawns = pieces[0];
    var bishops: u64 = pieces[1];
    var knights: u64 = pieces[2];
    var rooks: u64 = pieces[3];
    var queens: u64 = pieces[4];


    while(bishops > 0): (bishops = bit_set.popLstb(bishops)){
        move_set_list.add(lookup_tables.getBishopMoveSet(@intCast(@ctz(bishops)), occ).mask, @intCast(@ctz(bishops)));
    }

    while(knights > 0): (knights = bit_set.popLstb(knights)){
        move_set_list.add(lookup_tables.getKnightMoveSet(@intCast(@ctz(knights))).mask, @intCast(@ctz(knights)));
    }

    while(rooks > 0): (rooks = bit_set.popLstb(rooks)){
        move_set_list.add(lookup_tables.getRookMoveSet(@intCast(@ctz(rooks)), occ).mask, @intCast(@ctz(rooks)));
    }   

    while(queens > 0): (queens = bit_set.popLstb(queens)){
        move_set_list.add(lookup_tables.getQueenMoveSet(@intCast(@ctz(queens)), occ).mask, @intCast(@ctz(queens)));
    }

    for(0..move_set_list.count)|i|{
        move_set_list.moveSets[i] &= ~team;
    }

    self.generatePawnMoves2(&move_list, 
                        pawns, 
                        .{
                            .legalSquares =  ~(enemy | team),
                            .legalCaptures =  enemy,
                            .from = 0,
                        }, 
                        @as(u64, 1) << self.en_passant_sq, 
                        ~occ);

    self.generateKingCastleMoves(&move_list, 
                                        kingSquare, 
                                        enemyAttacks, 
                                        team, enemy
                                        );
    

    storePieceMoves(&move_list, .{
            .legalSquares = kingMoves & ~enemy,
            .legalCaptures = kingMoves & enemy,
            .from = @intCast(@ctz(king)),
    });

    for(0..move_set_list.count) |i|{
        const moveset = move_set_list.moveSets[i];

        storePieceMoves(&move_list, .{
            .legalSquares = moveset & ~enemy,
            .legalCaptures = moveset & enemy,
            .from = move_set_list.from[i],
        });
    }

    return move_list;
}


fn generatePawnMoves2(self: *Self, moveList: *MoveList, bitboard: u64, genInfo: PieceStoreMoveInfo, enPassantSquare: u64, empty: u64) void{
    var normalPush: u64 = 0;
    var doublePush: u64 = 0;
    var promotions: u64 = 0;
    var offset: i6 = 0;
    var attackSet: u64 = 0;
    var captures: u64 = 0;
    var promotionsWithCapture: u64 = 0;

    if(self.to_play == .white){
        normalPush = ((bitboard << 8) & empty);
        doublePush = ((normalPush & rank3) << 8) & empty;

        normalPush &= genInfo.legalSquares;
        doublePush &= genInfo.legalSquares;

        promotions = normalPush & rank8;
        normalPush ^= promotions;
        offset = -8;

        attackSet = (((bitboard << 9) & notAFile ) | ((bitboard << 7 ) & notHFile));
        promotionsWithCapture = attackSet & rank8 & genInfo.legalCaptures;
        attackSet ^= promotionsWithCapture;
    }else{
        normalPush = (bitboard >> 8 & empty);   
        doublePush = ((normalPush & rank6) >> 8) & empty;

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
    
    while(normalPush > 0): (normalPush &= normalPush - 1){
        const sq: u6 = @intCast(@ctz(normalPush));
        moveList.add(
                Move.New(
                    sq +% @as(u6, @bitCast(offset)), 
                    sq, 
                    .quietMove)
                );
    }

    while(doublePush > 0): (doublePush &= doublePush - 1){
        const sq: u6 = @intCast(@ctz(doublePush));
        moveList.add(
                Move.New( 
                    sq +% @as(u6, @bitCast(offset * 2)), 
                    sq, 
                    .doublePawnPush)
               );
    }

    while(promotions > 0): (promotions &= promotions - 1){
        const sq: u6 = @intCast(@ctz(promotions));
        inline for(0..4) |i|{
            moveList.add(
                    Move.New(
                        sq +% @as(u6, @bitCast(offset)), 
                        sq, 
                        @enumFromInt(Move.Flags.toInt(.knightPromotion) + @as(u4, @intCast(i))))
                    );
        } 
    }

    while(captures > 0): (captures = bit_set.popLstb(captures)){
        const sq: u6 = @intCast(@ctz(captures));
        var attackers: u64 = lookup_tables.getPawnAttackSet(sq, @intFromEnum(self.to_play) ^ @as(u1, 1)).mask & bitboard;
        while(attackers > 0): (attackers = bit_set.popLstb(attackers)){
            moveList.add(
                    Move.New(
                        @intCast(@ctz(attackers)), 
                        sq, 
                        .capture)
                    );
        }
    }

    if((attackSet & enPassantSquare) > 0){
        const sq: u6 = self.en_passant_sq;
        var attackers: u64 = lookup_tables.getPawnAttackSet(sq, @intFromEnum(self.to_play) ^ @as(u1, 1)).mask & bitboard;
        while(attackers > 0): (attackers = bit_set.popLstb(attackers)){
            moveList.add(
                    Move.New( 
                        @intCast(@ctz(attackers)), 
                        sq, 
                        .epCapture
                    )
            );
        }
    }

    while(promotionsWithCapture > 0): (promotionsWithCapture = bit_set.popLstb(promotionsWithCapture)){
        const sq: u6 = @intCast(@ctz(promotionsWithCapture));
        var attackers: u64 = lookup_tables.getPawnAttackSet(sq, ~@intFromEnum(self.to_play)).mask & bitboard;
        while(attackers > 0): (attackers = bit_set.popLstb(attackers)){            
            inline for(0..4) |i|{
                moveList.add(
                        Move.New( 
                            @intCast(@ctz(attackers)), 
                            sq, 
                            @enumFromInt(Move.Flags.toInt(.knightPromotionCapture) + @as(u4, @intCast(i)))
                            )
                        );
            }
        }
    }
}

fn generateKingCastleMoves(self: *Self, moveList: *MoveList, kingSquare: u6, enemyAttackSet: u64, team: u64, enemy: u64) void{
    const queenSideCastleMask: u64 = @as(u64, 0xc) << ((kingSquare >> 3) << 3);
    const kingSideCastleMask: u64 = @as(u64, 0x60) << ((kingSquare >> 3) << 3);
    const queenSideCastleMaskB: u64 = (queenSideCastleMask >> @as(u6, 1)) | queenSideCastleMask; 

    const castleRights: u2 = @intCast((self.castle_rights >> (@as(u2, @intFromBool(self.to_play == .black)) << 1)) & 0x3);

    const kingSideCastle: bool = (castleRights & 0x1) > 0 and (kingSideCastleMask & (enemyAttackSet | team | enemy)) == 0;
    const queenSideCastle: bool = (castleRights & 0x2) > 0 and (queenSideCastleMask & enemyAttackSet) == 0 and queenSideCastleMaskB & (team | enemy) == 0;

    if(kingSideCastle){
        moveList.add(
            Move.New(
                    kingSquare, 
                    kingSquare + 2, 
                    .kingSideCastle
                    )
        );
    }

    if(queenSideCastle){
        moveList.add(
            Move.New( 
                    kingSquare, 
                    kingSquare - 2, 
                    .queenSideCastle
                    )
        );
    }
}

fn getAttackSet(self: *Self, color: Side, occ: u64) u64 {
    const start: u4 = 6 * @as(u4, @intFromBool(color == .black));
    const end: u4 = 6 + (6 * @as(u4, @intFromBool(color == .black)));

    var attackSet: u64 = 0;

    const pieces = self.bitboards[start..end];

    //std.log.debug("pawns {}\n", .{pieces[0]});

    var pawnAttacks: u64 = 0;

    if(color == .white){
        pawnAttacks = (pieces[0] << 9 & notAFile) | (pieces[0] << 7 & notHFile);
    }else{
        pawnAttacks = (pieces[0] >> 7 & notAFile) | (pieces[0] >> 9 & notHFile);
    }

    //std.log.debug("{}\n", .{pawnAttacks});

    attackSet |= pawnAttacks;
    attackSet |= lookup_tables.getKingMoveSet(@intCast(@ctz(pieces[5]))).mask;

    var bishops: u64 = pieces[1];
    while (bishops > 0) : (bishops &= bishops - 1) {
        attackSet |= lookup_tables.getBishopMoveSet(@intCast(@ctz(bishops)), occ).mask;
    }

    var knights: u64 = pieces[2];
    while (knights > 0) : (knights &= knights - 1) {
        attackSet |= lookup_tables.getKnightMoveSet(@intCast(@ctz(knights))).mask;
    }

    var rooks: u64 = pieces[3];
    while (rooks > 0) : (rooks &= rooks - 1) {
        attackSet |= lookup_tables.getRookMoveSet(@intCast(@ctz(rooks)), occ).mask;
    }

    var queens: u64 = pieces[4];
    while (queens > 0) : (queens &= queens - 1) {
        attackSet |= lookup_tables.getQueenMoveSet(@intCast(@ctz(queens)), occ).mask;
    }

    return attackSet;
}

fn getSquareAttackers(self: *Self, square: u6, side: Side, occupancy: u64) u64{
    const blackToPlay: u4 = @intFromBool(side == .black);
    const start: u4 = 6 * blackToPlay;
    const end: u4 = 6 + 6 * blackToPlay;

    const pieces = self.bitboards[start..end];

    const rqattackers: u64 = lookup_tables.getRookMoveSet(square, occupancy).mask & (pieces[3] | pieces[4]);
    const bqattackers: u64 = lookup_tables.getBishopMoveSet(square, occupancy).mask & (pieces[1] | pieces[4]);
    const pattackers: u64 = lookup_tables.getPawnAttackSet(square, @intFromEnum(side) ^ @as(u1, 1)).mask & pieces[0];
    const nattackers: u64 = lookup_tables.getKnightMoveSet(square).mask & pieces[2];
    const kattackers: u64 = lookup_tables.getKingMoveSet(square).mask & pieces[5];

    return rqattackers | bqattackers | pattackers | nattackers | kattackers;
}

fn isSquareAttacked(self: *Self, square: u6, side: Side, occupancy: u64) bool{
    return self.getSquareAttackers(square, side, occupancy) > 0;
}

pub fn isKingInCheck(self: *Self, side: Side, occupancy: u64) bool{
    if(side == .white){
        return self.isSquareAttacked(@intCast(@ctz(self.bitboards[@intFromEnum(PieceBitboardIdx.wKing)])), .black, occupancy);
    }else{
        return self.isSquareAttacked(@intCast(@ctz(self.bitboards[@intFromEnum(PieceBitboardIdx.bKing)])), .white, occupancy);
    }
}

pub inline fn isWhiteToPlay(self: Self) bool{
    return self.to_play == .white;
}

pub inline fn isBlackToPlay(self: Self) bool{
    return self.to_play == .black;
}

fn storePieceMoves(move_list: *MoveList, piece_info: PieceStoreMoveInfo) void{
    var moves: u64 = piece_info.legalSquares;
    var captures: u64 = piece_info.legalCaptures;

    while(moves > 0):(moves = bit_set.popLstb(moves)){
        move_list.add(
            Move.New(
                piece_info.from, 
                @intCast(@ctz(moves)), 
                .quietMove
                )
        );
    }

    while(captures > 0): (captures = bit_set.popLstb(captures)){
        move_list.add(
                Move.New(
                piece_info.from, 
                @intCast(@ctz(captures)), 
                .capture, 
                )
        );
    }
}

pub fn playStringMove(board: *Self, move_string: []const u8) void{ // no funcionara si es promocion
    const move_list = board.generateMoves();

    const fileFrom: u10 = move_string[0] - 'a';
    const rankFrom: u10 = move_string[1] - '1';
    const from: u10 = rankFrom * 8 + fileFrom;

    const fileTo: u10 = move_string[2] - 'a';
    const rankTo: u10 = move_string[3] - '1';
    const to: u10 = rankTo * 8 + fileTo;

    var m = Move.New(@intCast(from), @intCast(to), .quietMove);

    for(move_list.moves) |move|{{
        if(m.from() == move.from() and m.to() == move.to()){
            board.makeMove2(move);
        }
    }}
}