const std = @import("std");
const lookup_tables = @import("lookupTables.zig");
const bit_set = @import("bitSet.zig");

const Self = @This();

pub const Side = enum(u1) {
    white,
    black
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
};

pub const Move = struct {
    pieceBB: u4,
    colorBB: u4,
    captureBB: u4,
    colorCaptureBB: u4,
    from: u6,
    to: u6,
    pState: PreviousState,
    flags: Flags,

    const PreviousState = struct{
        epSquare: u6,
        castleRights: u4,
        board_flags: BoardFlags,
    };

    pub const Flags = enum(u4){
        quietMove,
        doublePawnPush,
        kingSideCastle,
        queenSideCastle,
        capture,
        epCapture,
        bishopPromotion,
        knightPromotion,
        rookPromotion,
        queenPromotion,
        bishopPromotionCapture,
        knightPromotionCapture,
        rookPromotionCapture,
        queenPromotionCapture
    };
};

pub const MoveList = struct {
    moves: [218]Move,
    count: u8,
    
    const PieceStoreMoveInfo = struct {
        legalSquares: u64,
        legalCaptures: u64,
        from: u6,
        currentPieceBB: u4,
        colorToPlayBB: u4,
        enemyColorBB: u4,
    };

    pub inline fn add(self: *MoveList, 
                            from: u6, to: u6, 
                            flags: Move.Flags, 
                            colorBB: u4, 
                            pieceBB: u4, 
                            colorCaptureBB: u4,
                            capturePieceBB: u4) void{
        self.moves[self.count].from = from;
        self.moves[self.count].to = to;
        self.moves[self.count].flags = flags;
        self.moves[self.count].colorBB = colorBB;
        self.moves[self.count].pieceBB = pieceBB;
        self.moves[self.count].colorCaptureBB = colorCaptureBB;
        self.moves[self.count].captureBB = capturePieceBB;
        self.count += 1;
    }
};

const MoveSetList = struct {
    moveSets: [18]u64,
    pieceBitboardIdx: [18]u4,
    from: [18]u6,
    count: u6,

    pub fn add(self: *@This(), moveSet: u64, pieceBitbordIdx: u4, from: u6) void{
        self.moveSets[self.count] = moveSet;
        self.pieceBitboardIdx[self.count] = pieceBitbordIdx;
        self.from[self.count] = from;
        self.count += 1;
    }
};

const FenError = error{
    InvalidFen,
};

const BoardFlags = enum{
    none,
    checkmate,
    stealmate,
    fiftymove,
    threerepetition
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

bitboards: [15]u64, // bitboard representation for the board

to_play: Side,

castle_rights: u4,  // bit 1 = K, bit 2 = Q, bit 3 = k, bit 4 = q

empty: u64, 

en_passant_sq: u6,

half_moves: u16,

move_number: u16,

flags: BoardFlags,

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
            'q' => {bb = @intFromEnum(PieceBitboardIdx.bQueen);},
            'k' => {bb = @intFromEnum(PieceBitboardIdx.bKing);},

            'P' => {bb = @intFromEnum(PieceBitboardIdx.wPawn);},
            'B' => {bb = @intFromEnum(PieceBitboardIdx.wBishop);},
            'N' => {bb = @intFromEnum(PieceBitboardIdx.wKnight);},
            'R' => {bb = @intFromEnum(PieceBitboardIdx.wRook);},
            'Q' => {bb = @intFromEnum(PieceBitboardIdx.wQueen);},
            'K' => {bb = @intFromEnum(PieceBitboardIdx.wKing);},
            else => {return FenError.InvalidFen;},
        }

        self.bitboards[bb] ^= sq;

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
    }else if(std.mem.eql(u8, whiteToPlay, "b")){
        self.to_play = .black;
    }else{
        return FenError.InvalidFen;
    }

    const castleRights = fenTokens.next().?;

    for(0..castleRights.len) |i|{
        switch (castleRights[i]) {
            'K' => {self.castle_rights ^= 0x1;},
            'Q' => {self.castle_rights ^= 0x2;},
            'k' => {self.castle_rights ^= 0x4;},
            'q' => {self.castle_rights ^= 0x8;},
            else => {return FenError.InvalidFen;},
        }
    }

    const enPassantSquare = fenTokens.next().?;

    if(!std.mem.eql(u8, enPassantSquare, "-")){
        const fileFrom: u10 = enPassantSquare[0] - 'a';
        const rankFrom: u10 = enPassantSquare[1] - '1';
        const sq: u10 = rankFrom * 8 + fileFrom;

        if(!(rankFrom == 7 or rankFrom == 3)){
            return FenError.InvalidFen;
        }

        self.en_passant_sq = @intCast(sq);
    }
}

pub fn restartPos(self: *Self) void{
    self.setPos(default_fen) catch unreachable;
}


pub fn isCheckMate(self: *Self) bool{
    return self.flags == .checkmate;
}

pub fn isDraw(self: *Self) bool{
    return self.flags == .stealmate;
}

pub fn getFen(self: *Self) []u8{
    _ = self;

    const fen: [92]u8 = @splat(0);

    return fen;
}

fn clearBoard(self: *Self) void{
    self.bitboards = @splat(0);
    self.castle_rights = 0;
    self.empty = 0;
    self.en_passant_sq = 0;
    self.to_play = .white;
    self.flags = .none;
}

pub fn makeMove(self: *Self, move: *Move) void{
    move.pState.castleRights = self.castle_rights;
    move.pState.epSquare = self.en_passant_sq;
    move.pState.board_flags = self.flags;

    const from = @as(u64, 1) << move.from;
    const to = @as(u64, 1) << move.to;
    const fromTo = from | to;

    const isDoublePawnPush: u6 = @bitCast(-@as(i6, @intFromBool(move.flags == Move.Flags.doublePawnPush)));
    const isEnPassant: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.epCapture)));
    const isCapture: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.capture or @intFromEnum(move.flags) >= 10)));
    const isKingSideCastle: u64 =  @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.kingSideCastle)));
    const isQueenSideCastle: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.queenSideCastle)));
    const rookBB: u4 = if(self.to_play == .white) @intFromEnum(PieceBitboardIdx.wRook)
                        else  @intFromEnum(PieceBitboardIdx.bRook);
    const enemyRookBB: u4 = if(self.to_play == .white) @intFromEnum(PieceBitboardIdx.bRook)
                            else  @intFromEnum(PieceBitboardIdx.wRook);

    const shift: u2 = if(self.to_play == .white) 0 else 2;
    const offset: i6 = if(self.to_play == .white) -8 else 8;
    const epCaptureSq: u64 = (@as(u64, 1) << (move.to +% @as(u6, @bitCast(offset)))) & isEnPassant;
    const isKingMove: u4 = if(move.pieceBB == @intFromEnum(PieceBitboardIdx.wKing) or
                                 move.pieceBB == @intFromEnum(PieceBitboardIdx.bKing))
                                @bitCast(@as(i4,-1)) else 
                                0;
    const leftRook: bool =  ((@as(u64, 0x1) << (56 * @as(u6, @intFromEnum(self.to_play)))) & self.bitboards[rookBB]) == 0;
    const rightRook: bool =  ((@as(u64, 0x80) << (56 * @as(u6, @intFromEnum(self.to_play)))) & self.bitboards[rookBB]) == 0;

    const rookFromTo: u64 = ((fromTo << 1) & isKingSideCastle) | ((from >> 4 | to << 1) & isQueenSideCastle);

    const generalMove = from | (to & ~isCapture) | epCaptureSq | rookFromTo;

    self.bitboards[move.pieceBB] ^= fromTo;    
    self.bitboards[rookBB] ^= rookFromTo;
    self.bitboards[move.colorBB] ^= fromTo | rookFromTo;

    self.en_passant_sq = (move.to +% @as(u6, @bitCast(offset))) & isDoublePawnPush;

    self.bitboards[move.captureBB] ^= (to & isCapture) | epCaptureSq;
    self.bitboards[move.colorCaptureBB] ^= (to & isCapture) | epCaptureSq;

    self.castle_rights &= ~((@as(u4, 0x3) << shift) & isKingMove);

    const enemyLeftRook: bool =     ((@as(u64, 0x1) << (56 * @as(u6, ~@intFromEnum(self.to_play)))) & self.bitboards[enemyRookBB]) == 0;
    const enemyRightRook: bool =    ((@as(u64, 0x80) << (56 * @as(u6, ~@intFromEnum(self.to_play)))) & self.bitboards[enemyRookBB]) == 0;

    if(@intFromEnum(move.flags) >= 6) {
        self.bitboards[move.pieceBB] ^= to;

        var idx: u4 = 0;
        const pieceBBTarget: u4 = @intFromEnum(PieceBitboardIdx.wBishop) + (6 * @as(u4, @intFromEnum(self.to_play)));

        idx += @intFromBool(move.flags == .knightPromotion or 
                            move.flags == .knightPromotionCapture);
        
        idx += @as(u4, @intFromBool(move.flags == .rookPromotion or 
                            move.flags == .rookPromotionCapture)) * 2;
        
        idx += @as(u4, @intFromBool(move.flags == .queenPromotion or 
                    move.flags == .queenPromotionCapture)) * 3;

        
        self.bitboards[pieceBBTarget + idx] ^= to;
    }

    if(rightRook){
        self.castle_rights &= ~(@as(u4, 1) << (@as(u2, @intFromEnum(self.to_play)) << 1));
    }
    if(leftRook){
        self.castle_rights &= ~(@as(u4, 2) << (@as(u2, @intFromEnum(self.to_play)) << 1));
    }

    if(enemyRightRook){
        self.castle_rights &= ~(@as(u4, 1) << (@as(u2, ~@intFromEnum(self.to_play)) << 1));
    }
    if(enemyLeftRook){
        self.castle_rights &= ~(@as(u4, 2) << (@as(u2, ~@intFromEnum(self.to_play)) << 1));
    }

    self.empty ^= generalMove;
    self.bitboards[@intFromEnum(PieceBitboardIdx.all)] ^= generalMove;

    self.to_play = if (self.to_play == .white) .black else .white;
}

pub fn unmakeMove(self: *Self, move: Move) void{
    self.en_passant_sq = move.pState.epSquare;
    self.castle_rights = move.pState.castleRights;
    self.flags = move.pState.board_flags;
    
    const from = @as(u64, 1) << move.from;
    const to = @as(u64, 1) << move.to;

    const fromTo = from | to;

    const isCapture: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.capture or @intFromEnum(move.flags) >= 10)));
    const isEnPassant: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.epCapture)));
    const offset: i6 = if(self.to_play == .white) 8 else -8;
    const epSquare = (@as(u64, 1) << (move.to +% @as(u6, @bitCast(offset)))) & isEnPassant;
    const isKingSideCastle: u64 =  @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.kingSideCastle)));
    const isQueenSideCastle: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.queenSideCastle)));
    self.to_play = if (self.to_play == .white) .black else .white;
    const rookBB: u4 = if(self.to_play == .white) @intFromEnum(PieceBitboardIdx.wRook)
                            else  @intFromEnum(PieceBitboardIdx.bRook);
    
    const rookFromTo: u64 = ((fromTo << 1) & isKingSideCastle) | ((from >> 4 | to << 1) & isQueenSideCastle);

    const generalMove = (from | (to & ~isCapture)) | epSquare | rookFromTo;

   if(@intFromEnum(move.flags) >= 6) {
        self.bitboards[move.pieceBB] ^= to;

        var idx: u4 = 0;
        const pieceBBTarget: u4 = @intFromEnum(PieceBitboardIdx.wBishop) + (6 * @as(u4, @intFromEnum(self.to_play)));

        idx += @intFromBool(move.flags == .knightPromotion or 
                            move.flags == .knightPromotionCapture);
        
        idx += @as(u4, @intFromBool(move.flags == .rookPromotion or 
                            move.flags == .rookPromotionCapture)) * 2;
        
        idx += @as(u4, @intFromBool(move.flags == .queenPromotion or 
                    move.flags == .queenPromotionCapture)) * 3;

        
        self.bitboards[pieceBBTarget + idx] ^= to;
    }

    self.bitboards[move.pieceBB] ^= fromTo;
    self.bitboards[rookBB] ^= rookFromTo;
    self.bitboards[move.colorBB] ^= fromTo | rookFromTo;
    
    self.bitboards[move.captureBB] ^= (to & isCapture) | epSquare;
    self.bitboards[move.colorCaptureBB] ^= (to & isCapture) | epSquare;

    self.empty ^= generalMove; 
    self.bitboards[@intFromEnum(PieceBitboardIdx.all)] ^= generalMove;
}

pub fn generateMoves(self: *Self) MoveList{
    const blackToPlay: u4 = @bitCast(-@as(i4, @intFromBool(self.to_play == .black)));
    const startPieceTeamIdx: u4 = (6 & blackToPlay);
    const endPieceTeamIdx: u4 = 6 + (6 & blackToPlay);
    const startPieceEnemyIdx: u4 = 6 & ~blackToPlay;
    const endPieceEnemyIdx: u4 = 6 + (6 & ~blackToPlay);

    const pieces: []u64 = self.bitboards[startPieceTeamIdx..endPieceTeamIdx];
    const king: u64 = pieces[5];

    const colorBB = if(self.to_play == .white) @intFromEnum(PieceBitboardIdx.white) else @intFromEnum(PieceBitboardIdx.black);
    const colorCaptureBB = if(self.to_play == .white) @intFromEnum(PieceBitboardIdx.black) else @intFromEnum(PieceBitboardIdx.white);

    const enemyPieces: []u64 = self.bitboards[startPieceEnemyIdx..endPieceEnemyIdx];

    const teamOccIdx = (@intFromEnum(PieceBitboardIdx.white) & ~blackToPlay) | (@intFromEnum(PieceBitboardIdx.black) & blackToPlay);
    const enemyOccIdx = (@intFromEnum(PieceBitboardIdx.white) & blackToPlay) | (@intFromEnum(PieceBitboardIdx.black) & ~blackToPlay);

    const team: u64 = self.bitboards[teamOccIdx];

    const enemy: u64 = self.bitboards[enemyOccIdx];

    const occ: u64 = team | enemy;

    const kingSquare: u6 = @intCast(@ctz(king));

    const enemyAttacks: u64 = self.getAttackSet(if(self.to_play == .white) Side.black else Side.white, occ ^ pieces[5]);

    //std.log.debug("{}\n", .{enemyAttacks});

    const is_king_in_check: bool = (king & enemyAttacks) > 0;
  
    const kingMoves: u64 = lookup_tables.getKingMoves(kingSquare) & ~(enemyAttacks | team);

    const pawnAttacks: u64 = lookup_tables.getPawnAtt(kingSquare, @intFromEnum(self.to_play));
    const bishopRays: u64 = lookup_tables.getBishopMoves(kingSquare, occ);
    const kgniht_attacks: u64 = lookup_tables.getKnightMoves(kingSquare);
    const rookRays: u64 = lookup_tables.getRookMoves(kingSquare, occ);

    const potentialPawnAttackers: u64 = pawnAttacks & enemyPieces[0];
    const potentialBishopAttackers: u64 = bishopRays & (enemyPieces[1] | enemyPieces[4]);
    const potentialKnightAttackers: u64 = kgniht_attacks & enemyPieces[2];
    const potentialRookAttackers: u64 = rookRays & (enemyPieces[3] | enemyPieces[4]);

    const whiteToPlay: bool = self.to_play == .white;

    const kingBB: u4 = if(whiteToPlay) @intFromEnum(PieceBitboardIdx.wKing) else @intFromEnum(PieceBitboardIdx.bKing);
    const pawnBB: u4 = if(whiteToPlay) @intFromEnum(PieceBitboardIdx.wPawn) else @intFromEnum(PieceBitboardIdx.bPawn);
    const bishopBB: u4 = if(whiteToPlay) @intFromEnum(PieceBitboardIdx.wBishop) else @intFromEnum(PieceBitboardIdx.bBishop);
    const knightBB: u4 = if(whiteToPlay) @intFromEnum(PieceBitboardIdx.wKnight) else @intFromEnum(PieceBitboardIdx.bKnight);
    const rookBB: u4 = if(whiteToPlay) @intFromEnum(PieceBitboardIdx.wRook) else @intFromEnum(PieceBitboardIdx.bRook);
    const queenBB: u4 = if(whiteToPlay) @intFromEnum(PieceBitboardIdx.wQueen) else @intFromEnum(PieceBitboardIdx.bQueen);

    var move_list: MoveList = .{
            .count = 0,
            .moves = undefined,
    };

    if(@popCount(potentialPawnAttackers | potentialBishopAttackers | potentialKnightAttackers | potentialRookAttackers) > 1){

        self.storePieceMoves(
            &move_list,
            .{
            .legalSquares = kingMoves & ~enemy,
            .legalCaptures = kingMoves & enemy,
            .from = kingSquare,
            .currentPieceBB = kingBB,
            .colorToPlayBB = colorBB,
            .enemyColorBB = colorCaptureBB,
        });

        self.storePieceMoves(&move_list, 
        .{
            .legalSquares = kingMoves & ~enemy,
            .legalCaptures = kingMoves & enemy,
            .from = kingSquare,
            .currentPieceBB = kingBB,
            .colorToPlayBB = colorBB,
            .enemyColorBB = colorCaptureBB,
        });

        if(move_list.count == 0){
            self.flags = .checkmate;
        }

        return move_list;
    }

    var potential_pinned_pieces: u64 = rookRays & team;


    var rqAttackers: u64 = lookup_tables.getRookMask(kingSquare) & (enemyPieces[4] | enemyPieces[3]);
    var pinnedPiecesMask: u64 = 0;

    while(rqAttackers > 0):(rqAttackers = bit_set.popLstb(rqAttackers)){
        pinnedPiecesMask |= lookup_tables.getRookMoves(@ctz(rqAttackers), occ) & potential_pinned_pieces;
    }

    potential_pinned_pieces = bishopRays & team;
    var bqAttackers: u64 = lookup_tables.getBishopMask(kingSquare) & (enemyPieces[4] | enemyPieces[1]);

    while(bqAttackers > 0):(bqAttackers = bit_set.popLstb(bqAttackers)){
        pinnedPiecesMask |= lookup_tables.getBishopMoves(@ctz(bqAttackers), occ) & potential_pinned_pieces;
    }

    const pawns_not_pinned: u64 = pieces[0] & ~pinnedPiecesMask;
    const bishops_not_pinned: u64 = pieces[1] & ~pinnedPiecesMask;
    const knights_not_pinned: u64 = pieces[2] & ~pinnedPiecesMask;
    const rooks_not_pinned: u64 = pieces[3] & ~pinnedPiecesMask;
    const queens_not_pinned: u64 = pieces[4] & ~pinnedPiecesMask;

    const pawns_pinned: u64 = pieces[0] & pinnedPiecesMask;
    const bishop_pinned: u64 = pieces[1] & pinnedPiecesMask;
    const rooks_pinned: u64 = pieces[3] & pinnedPiecesMask;
    const queens_pinned: u64 = pieces[4] & pinnedPiecesMask;

    var move_set_list: MoveSetList = .{
        .count = 0,
        .from = undefined,
        .moveSets = undefined,
        .pieceBitboardIdx = undefined,
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

    while(bishops > 0): (bishops = bit_set.popLstb(bishops)){
        move_set_list.add(lookup_tables.getBishopMoves(@ctz(bishops), occ), bishopBB, @intCast(@ctz(bishops)));
    }

    while(knights > 0): (knights = bit_set.popLstb(knights)){
        move_set_list.add(lookup_tables.getKnightMoves(@ctz(knights)), knightBB, @intCast(@ctz(knights)));
    }

    while(rooks > 0): (rooks = bit_set.popLstb(rooks)){
        move_set_list.add(lookup_tables.getRookMoves(@ctz(rooks), occ), rookBB, @intCast(@ctz(rooks)));
    }

    while(queens > 0): (queens = bit_set.popLstb(queens)){
        move_set_list.add(lookup_tables.getQueenMoves(@ctz(queens), occ), queenBB, @intCast(@ctz(queens)));
    }

    if(!is_king_in_check){
        mask = ~team;
        const ghost_bishop = lookup_tables.getBishopMask(kingSquare);

        while(bishops_p > 0): (bishops_p = bit_set.popLstb(bishops_p)){
            const bishopMoves: u64 = lookup_tables.getBishopMoves(@ctz(bishops_p), occ) & ghost_bishop;
            move_set_list.add(bishopMoves, bishopBB, @intCast(@ctz(bishops_p)));
        }

        while(rooks_p > 0): (rooks_p = bit_set.popLstb(rooks_p)){
            const rookMoves: u64 = lookup_tables.getRookMoves(@ctz(rooks_p), occ) & lookup_tables.getRookMask(kingSquare);
            move_set_list.add(rookMoves, rookBB, @intCast(@ctz(rooks_p)));
        }

        while(queens_pb > 0): (queens_pb = bit_set.popLstb(queens_pb)){
            const queen_moves: u64 = lookup_tables.getBishopMoves(@ctz(queens_pb), occ) & ghost_bishop;
            move_set_list.add(queen_moves, queenBB, @intCast(@ctz(queens_pb)));
        }

        while(queens_pr > 0): (queens_pr = bit_set.popLstb(queens_pr)){
            const queen_moves: u64 = lookup_tables.getRookMoves(@ctz(queens_pr), occ) & lookup_tables.getRookMask(kingSquare);
            move_set_list.add(queen_moves, queenBB, @intCast(@ctz(queens_pr)));
        }
    }else{
        check = true;

        if(potentialPawnAttackers != 0 or potentialKnightAttackers != 0){
            mask = potentialPawnAttackers | potentialKnightAttackers;
        }else if(potentialBishopAttackers != 0){
            mask = (lookup_tables.getBishopMoves(@ctz(potentialBishopAttackers), occ) & bishopRays) | potentialBishopAttackers;
        }else if(potentialRookAttackers != 0){
            mask = (lookup_tables.getRookMoves(@ctz(potentialRookAttackers), occ) & rookRays) | potentialRookAttackers;
        }
    }

    for(0..move_set_list.count) |i|{
        move_set_list.moveSets[i] &= mask;
    }

    const enPassant = self.getEnPassantSquare(pawnBB ^ 6, 
                    colorCaptureBB, 
                    colorBB,
                    pawns_not_pinned | (pawns_pinned & bishopRays), 
                    pawnBB, 
                    king);

    self.generatePawnMoves2(&move_list, 
                        pawns_not_pinned, 
                        .{
                            .legalSquares = mask & ~enemy,
                            .legalCaptures = mask & enemy,
                            .from = 0,
                            .currentPieceBB = pawnBB,
                            .colorToPlayBB = colorBB,
                            .enemyColorBB = colorCaptureBB,
                        }, 
                        enPassant, 
                        ~occ);
    
    if(!check){
        self.generateKingCastleMoves(&move_list, 
                                        kingSquare, 
                                        enemyAttacks, 
                                        team, enemy, 
                                        colorBB, 
                                        kingBB);

        if(pawns_pinned > 0){
            self.generatePawnMoves2( // the pawns that are behind and in front of the king and are pinned can't capture, this only generate those moves
                &move_list, 
                (pawns_pinned & ~(@as(u64, 0xFF) << ((kingSquare >> 3) * 8))) & lookup_tables.getRookMask(kingSquare), 
                .{
                    .legalSquares = mask & lookup_tables.getRookMask(kingSquare),
                    .legalCaptures = 0,
                    .from = 0,
                    .currentPieceBB = pawnBB,
                    .colorToPlayBB = colorBB,
                    .enemyColorBB = colorCaptureBB,
                }, 
                0,
                ~occ);

            self.generatePawnMoves2( //this generates the pawns that are pinned by a bishop
                &move_list, 
                pawns_pinned & bishopRays, 
                .{
                    .legalSquares = 0,
                    .legalCaptures = lookup_tables.getBishopMask(kingSquare) & (enemyPieces[4] | enemyPieces[1]),
                    .from = 0,
                    .currentPieceBB = pawnBB,
                    .colorToPlayBB = colorBB,
                    .enemyColorBB = colorCaptureBB,
                }, 
                enPassant & lookup_tables.getBishopMask(kingSquare),
            
                ~occ);
        }

    }

    self.storePieceMoves(&move_list, .{
            .legalSquares = kingMoves & ~enemy,
            .legalCaptures = kingMoves & enemy,
            .from = @intCast(@ctz(king)),
            .currentPieceBB = kingBB,
            .colorToPlayBB = colorBB,
            .enemyColorBB = colorCaptureBB
    });

    for(0..move_set_list.count) |i|{
        if(move_set_list.moveSets[i] == 0) continue;

        const moveset = move_set_list.moveSets[i];

        self.storePieceMoves(&move_list, .{
            .legalSquares = moveset & ~enemy,
            .legalCaptures = moveset & enemy,
            .from = move_set_list.from[i],
            .currentPieceBB = move_set_list.pieceBitboardIdx[i],
            .colorToPlayBB = colorBB,
            .enemyColorBB = colorCaptureBB
        });
    }

    if(move_list.count == 0){
        if(is_king_in_check){
            self.flags = .checkmate;
        }else{
            self.flags = .stealmate;
        }
    }

    return move_list;
}

fn getEnPassantSquare(self: *Self, captureBB: u4, colorCaptureBB: u4, colorBB: u4, tPawns: u64, pieceBB: u4, kingSquare: u64) u64{
    if(self.en_passant_sq != 0){
        var enPassantAttackers = lookup_tables.getPawnAtt(self.en_passant_sq, ~@intFromEnum(self.to_play)) & tPawns;

        if(@popCount(enPassantAttackers) == 0){
            return 0;
        }

        while(enPassantAttackers > 0): (enPassantAttackers = bit_set.popLstb(enPassantAttackers)){
            var move: Move = .{
                .to = self.en_passant_sq,
                .from = @intCast(@ctz(enPassantAttackers)),
                .captureBB = captureBB,
                .colorBB = colorBB,
                .colorCaptureBB = colorCaptureBB,
                .flags = .epCapture,
                .pieceBB = pieceBB,
                .pState = .{
                    .castleRights = self.castle_rights,
                    .epSquare = self.en_passant_sq,
                    .board_flags = self.flags,
                }
                
            };

            self.makeMove(&move);

            if(!self.isSquareAttacked(@intCast(@ctz(kingSquare)), self.to_play, self.bitboards[@intFromEnum(PieceBitboardIdx.all)])){
                self.unmakeMove(move);
                return @as(u64, 1) << self.en_passant_sq;
            }

            self.unmakeMove(move);
        }

        return 0;
    }

    return 0;
}

fn generatePawnMoves2(self: *Self, moveList: *MoveList, bitboard: u64, genInfo: MoveList.PieceStoreMoveInfo, enPassantSquare: u64, empty: u64) void{
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
                sq +% @as(u6, @bitCast(offset)), 
                sq, 
                .quietMove, 
                genInfo.colorToPlayBB, 
                genInfo.currentPieceBB, 
                genInfo.enemyColorBB, 
                0);
    }

    while(doublePush > 0): (doublePush &= doublePush - 1){
        const sq: u6 = @intCast(@ctz(doublePush));
        moveList.add(
                sq +% @as(u6, @bitCast(offset * 2)), 
                sq, 
                .doublePawnPush, 
                genInfo.colorToPlayBB, 
                genInfo.currentPieceBB, 
                genInfo.enemyColorBB, 
                0);
    }

    while(promotions > 0): (promotions &= promotions - 1){
        const sq: u6 = @intCast(@ctz(promotions));
        inline for(0..4) |i|{
            moveList.add(
                    sq +% @as(u6, @bitCast(offset)), 
                    sq, 
                    @enumFromInt(@intFromEnum(Move.Flags.bishopPromotion) + @as(u4, @intCast(i))), 
                    genInfo.colorToPlayBB, 
                    genInfo.currentPieceBB, 
                    genInfo.enemyColorBB, 
                    0);
        } 
    }

    while(captures > 0): (captures = bit_set.popLstb(captures)){
        const sq: u6 = @intCast(@ctz(captures));
        const capturePieceBB: u4 = self.getPieceBitboardIdx(sq);
        var attackers: u64 = lookup_tables.getPawnAtt(sq, @intFromEnum(self.to_play) ^ @as(u1, 1)) & bitboard;
        while(attackers > 0): (attackers = bit_set.popLstb(attackers)){
            moveList.add(
                    @intCast(@ctz(attackers)), 
                    sq, 
                    .capture, 
                    genInfo.colorToPlayBB, 
                    genInfo.currentPieceBB, 
                    genInfo.enemyColorBB, 
                    capturePieceBB
                    );
        }
    }

    if((attackSet & enPassantSquare) > 0){
        const sq: u6 = self.en_passant_sq;
        var attackers: u64 = lookup_tables.getPawnAtt(sq, @intFromEnum(self.to_play) ^ @as(u1, 1)) & bitboard;
        while(attackers > 0): (attackers = bit_set.popLstb(attackers)){
            moveList.add(
                    @intCast(@ctz(attackers)), 
                    sq, 
                    .epCapture, 
                    genInfo.colorToPlayBB, 
                    genInfo.currentPieceBB, 
                    genInfo.enemyColorBB,
                    if(self.to_play == .white) @intFromEnum(PieceBitboardIdx.bPawn) else @intFromEnum(PieceBitboardIdx.wPawn) 
                    );
        }
    }

    while(promotionsWithCapture > 0): (promotionsWithCapture = bit_set.popLstb(promotionsWithCapture)){
        const sq: u6 = @intCast(@ctz(promotionsWithCapture));
        var attackers: u64 = lookup_tables.getPawnAtt(sq, ~@intFromEnum(self.to_play)) & bitboard;
        const captureBB: u4 = self.getPieceBitboardIdx(sq);
        while(attackers > 0): (attackers = bit_set.popLstb(attackers)){            
            inline for(0..4) |i|{
                moveList.add(
                        @intCast(@ctz(attackers)), 
                        sq, 
                        @enumFromInt(@intFromEnum(Move.Flags.bishopPromotionCapture) + @as(u4, @intCast(i))), 
                        genInfo.colorToPlayBB, 
                        genInfo.currentPieceBB, 
                        genInfo.enemyColorBB,
                        captureBB
                    );
            }
        }
    }

}

fn generateKingCastleMoves(self: *Self, moveList: *MoveList, kingSquare: u6, enemyAttackSet: u64, team: u64, enemy: u64, colorBB: u4, pieceBB: u4) void{
    const queenSideCastleMask: u64 = @as(u64, 0xc) << ((kingSquare >> 3) << 3);
    const kingSideCastleMask: u64 = @as(u64, 0x60) << ((kingSquare >> 3) << 3);
    const queenSideCastleMaskB: u64 = (queenSideCastleMask >> @as(u6, 1)) | queenSideCastleMask; 

    const castleRights: u2 = @intCast((self.castle_rights >> (@as(u2, @intFromBool(self.to_play == .black)) << 1)) & 0x3);

    const kingSideCastle: bool = (castleRights & 0x1) > 0 and (kingSideCastleMask & (enemyAttackSet | team | enemy)) == 0;
    const queenSideCastle: bool = (castleRights & 0x2) > 0 and (queenSideCastleMask & enemyAttackSet) == 0 and queenSideCastleMaskB & (team | enemy) == 0;

    if(kingSideCastle){
        moveList.add(
                        kingSquare, 
                        kingSquare + 2, 
                        .kingSideCastle, 
                        colorBB, 
                        pieceBB, 
                        0, 
                        0);
    }

    if(queenSideCastle){
        moveList.add(
                        kingSquare, 
                        kingSquare - 2, 
                        .queenSideCastle, 
                        colorBB, 
                        pieceBB, 
                        0, 
                        0);
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
    attackSet |= lookup_tables.getKingMoves(@intCast(@ctz(pieces[5])));

    var bishops: u64 = pieces[1];
    while (bishops > 0) : (bishops &= bishops - 1) {
        attackSet |= lookup_tables.getBishopMoves(@intCast(@ctz(bishops)), occ);
    }

    var knights: u64 = pieces[2];
    while (knights > 0) : (knights &= knights - 1) {
        attackSet |= lookup_tables.getKnightMoves(@intCast(@ctz(knights)));
    }

    var rooks: u64 = pieces[3];
    while (rooks > 0) : (rooks &= rooks - 1) {
        attackSet |= lookup_tables.getRookMoves(@intCast(@ctz(rooks)), occ);
    }

    var queens: u64 = pieces[4];
    while (queens > 0) : (queens &= queens - 1) {
        attackSet |= lookup_tables.getQueenMoves(@intCast(@ctz(queens)), occ);
    }

    return attackSet;
}

fn getPieceBitboardIdx(self: *Self, square: u6) u4{
    const pos = @as(u64, 1) << square;

    const wPawn: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[0] & pos) > 0)));
    const wBishop: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[1] & pos) > 0)));
    const wKnight: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[2] & pos) > 0)));
    const wRook: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[3] & pos) > 0)));
    const wQueen: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[4] & pos) > 0)));
    const wKing: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[5] & pos) > 0)));

    const bPawn: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[6] & pos) > 0)));
    const bBishop: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[7] & pos) > 0)));
    const bKnight: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[8] & pos) > 0)));
    const bRook: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[9] & pos) > 0)));
    const bQueen: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[10] & pos) > 0)));
    const bKing: u4 = @bitCast(-@as(i4, @intFromBool((self.bitboards[11] & pos) > 0)));

    return  (@intFromEnum(PieceBitboardIdx.wPawn) & wPawn) +
            (@intFromEnum(PieceBitboardIdx.wBishop) & wBishop) +
            (@intFromEnum(PieceBitboardIdx.wKnight) & wKnight) +
            (@intFromEnum(PieceBitboardIdx.wRook) & wRook) +
            (@intFromEnum(PieceBitboardIdx.wQueen) & wQueen) +
            (@intFromEnum(PieceBitboardIdx.wKing) & wKing) +
            (@intFromEnum(PieceBitboardIdx.bPawn) & bPawn) +
            (@intFromEnum(PieceBitboardIdx.bBishop) & bBishop) +
            (@intFromEnum(PieceBitboardIdx.bKnight) & bKnight) +
            (@intFromEnum(PieceBitboardIdx.bRook) & bRook) +
            (@intFromEnum(PieceBitboardIdx.bQueen) & bQueen) +
            (@intFromEnum(PieceBitboardIdx.bKing) & bKing);   
}

fn getSquareAttackers(self: *Self, square: u6, side: Side, occupancy: u64) u64{
    const blackToPlay: u4 = @intFromBool(side == .black);
    const start: u4 = 6 * blackToPlay;
    const end: u4 = 6 + 6 * blackToPlay;

    const pieces = self.bitboards[start..end];

    const rqattackers: u64 = lookup_tables.getRookMoves(square, occupancy) & (pieces[3] | pieces[4]);
    const bqattackers: u64 = lookup_tables.getBishopMoves(square, occupancy) & (pieces[1] | pieces[4]);
    const pattackers: u64 = lookup_tables.getPawnAtt(square, @intFromEnum(side) ^ @as(u1, 1)) & pieces[0];
    const nattackers: u64 = lookup_tables.getKnightMoves(square) & pieces[2];
    const kattackers: u64 = lookup_tables.getKingMoves(square) & pieces[5];

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

fn storePieceMoves(self: *Self, move_list: *MoveList, piece_info: MoveList.PieceStoreMoveInfo) void{
    var moves: u64 = piece_info.legalSquares;
    var captures: u64 = piece_info.legalCaptures;

    while(moves > 0):(moves = bit_set.popLstb(moves)){
        move_list.add(
            piece_info.from, 
            @intCast(@ctz(moves)), 
            .quietMove, 
            piece_info.colorToPlayBB, 
            piece_info.currentPieceBB,
            0,
            0
        );
    }

    while(captures > 0): (captures = bit_set.popLstb(captures)){
        move_list.add(
            piece_info.from, 
            @intCast(@ctz(captures)), 
            .capture, 
            piece_info.colorToPlayBB, 
            piece_info.currentPieceBB,
            piece_info.enemyColorBB,
            self.getPieceBitboardIdx(@intCast(@ctz(captures)))
        );
    }
}

