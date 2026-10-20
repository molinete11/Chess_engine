const std = @import("std");
const Position = @import("position.zig");
const MoveList = @import("moveList.zig");
const lot = @import("lot.zig");
const Move = @import("move.zig");
const bit_set = @import("bitSet.zig");

const assert = std.debug.assert;

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

pub const MoveType = enum {
    all,
    captures,
};

pub fn genMoves(pos: *Position, comptime T: MoveType) MoveList{
    return generateMoves(pos, T);
}


inline fn generateMoves(position: *Position, comptime T: MoveType) MoveList {
    //std.debug.print("sq {}\n", .{self.en_passant_sq});
    const team = position.teamPieces();
    const king: u64 = team[5];

    const enemy = position.enemyPieces();

    const teamOcc: u64 = position.teamOccupancy();

    const enemyOcc: u64 = position.enemyOccupancy();

    const occ: u64 = position.notEmpty();

    const kingSquare: u6 = @intCast(@ctz(king));

    const enemyAttacks: u64 = position.getAttackSet(if (position.to_play == .white) .black else .white, occ ^ king);

    const is_king_in_check: bool = (king & enemyAttacks) > 0;

    const kingMoves: u64 = lot.getKingMoveSet(kingSquare).mask & ~(enemyAttacks | teamOcc);

    const pawnAttacks: u64 = lot.getPawnAttackSet(kingSquare, position.to_play.toInt()).mask;
    const bishopRays: u64 = lot.getBishopMoveSet(kingSquare, occ).mask;
    const knight_attacks: u64 = lot.getKnightMoveSet(kingSquare).mask;
    const rookRays: u64 = lot.getRookMoveSet(kingSquare, occ).mask;

    const potentialPawnAttackers: u64 = pawnAttacks & enemy[0];
    const potentialBishopAttackers: u64 = bishopRays & (enemy[1] | enemy[4]);
    const potentialKnightAttackers: u64 = knight_attacks & enemy[2];
    const potentialRookAttackers: u64 = rookRays & (enemy[3] | enemy[4]);

    const ghost_rook: u64 = lot.getRookMask(kingSquare).mask;
    const ghost_bishop: u64 = lot.getBishopMask(kingSquare).mask;

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
        pinnedPiecesMask |= lot.getRookMoveSet(@ctz(rqAttackers), occ).mask & potential_pinned_pieces;
    }

    potential_pinned_pieces = bishopRays & teamOcc;
    var bqAttackers: u64 = ghost_bishop & (enemy[4] | enemy[1]);

    while (bqAttackers > 0) : (bqAttackers = bit_set.popLstb(bqAttackers)) {
        pinnedPiecesMask |= lot.getBishopMoveSet(@ctz(bqAttackers), occ).mask & potential_pinned_pieces;
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
        move_set_list.add(lot.getBishopMoveSet(@ctz(bishops), occ).mask, @intCast(@ctz(bishops)));
    }

    while (knights > 0) : (knights = bit_set.popLstb(knights)) {
        move_set_list.add(lot.getKnightMoveSet(@ctz(knights)).mask, @intCast(@ctz(knights)));
    }

    while (rooks > 0) : (rooks = bit_set.popLstb(rooks)) {
        move_set_list.add(lot.getRookMoveSet(@ctz(rooks), occ).mask, @intCast(@ctz(rooks)));
    }

    while (queens > 0) : (queens = bit_set.popLstb(queens)) {
        move_set_list.add(lot.getQueenMoveSet(@ctz(queens), occ).mask, @intCast(@ctz(queens)));
    }

    if (!is_king_in_check) {
        mask = ~teamOcc;
        
        while (bishops_p > 0) : (bishops_p = bit_set.popLstb(bishops_p)) {
            const bishopMoves: u64 = lot.getBishopMoveSet(@ctz(bishops_p), occ).mask & ghost_bishop;
            move_set_list.add(bishopMoves, @intCast(@ctz(bishops_p)));
        }

        while (rooks_p > 0) : (rooks_p = bit_set.popLstb(rooks_p)) {
            const rookMoves: u64 = lot.getRookMoveSet(@ctz(rooks_p), occ).mask & ghost_rook;
            move_set_list.add(rookMoves, @intCast(@ctz(rooks_p)));
        }

        while (queens_pb > 0) : (queens_pb = bit_set.popLstb(queens_pb)) {
            const queen_moves: u64 = lot.getBishopMoveSet(@ctz(queens_pb), occ).mask & ghost_bishop;
            move_set_list.add(queen_moves, @intCast(@ctz(queens_pb)));
        }

        while (queens_pr > 0) : (queens_pr = bit_set.popLstb(queens_pr)) {
            const queen_moves: u64 = lot.getRookMoveSet(@ctz(queens_pr), occ).mask & ghost_rook;
            move_set_list.add(queen_moves, @intCast(@ctz(queens_pr)));
        }
    } else {
        check = true;

        if (potentialPawnAttackers != 0 or potentialKnightAttackers != 0) {
            mask = potentialPawnAttackers | potentialKnightAttackers;
        } else if (potentialBishopAttackers != 0) {
            mask = (lot.getBishopMoveSet(@ctz(potentialBishopAttackers), occ).mask & bishopRays) | potentialBishopAttackers;
        } else if (potentialRookAttackers != 0) {
            mask = (lot.getRookMoveSet(@ctz(potentialRookAttackers), occ).mask & rookRays) | potentialRookAttackers;
        }
    }

    if(T == .captures){
        mask = enemyOcc;
    }

    for (0..move_set_list.count) |i| {
        move_set_list.moveSets[i] &= mask;
    }

    const enPassant = getEnPassantSquare(position, pawns_not_pinned | (pawns_pinned & bishopRays), king);
    //std.debug.print("{}\n", .{enPassant});

    generatePawnMoves2(position, &move_list, pawns_not_pinned, .{
        .legalSquares = mask & ~enemyOcc,
        .legalCaptures = mask & enemyOcc,
        .from = 0,
    }, enPassant);

    if (!check) {

        if(T != .captures){
            generateKingCastleMoves(
                        position, 
                        &move_list, 
                        kingSquare, 
                        enemyAttacks, 
                        teamOcc, enemyOcc);
        }
        

        if (pawns_pinned > 0) {
            generatePawnMoves2( // the pawns that are behind and in front of the king and are pinned can't capture, this only generate those moves
                position,
                &move_list, (pawns_pinned & ~(@as(u64, 0xFF) << ((kingSquare >> 3) * 8))) & ghost_rook, .{
                    .legalSquares = mask & ghost_rook,
                    .legalCaptures = 0,
                    .from = 0,
                }, 0);

            generatePawnMoves2( //this generates the pawns that are pinned by a bishop
                position,
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

fn getEnPassantSquare(position: *Position, tPawns: u64, kingSquare: u64) u64 {
    assert(kingSquare != 0);
    if (position.en_passant_sq != 0) {

        var enPassantAttackers: u64 = lot.getPawnAttackSet(position.en_passant_sq, 
                                    position.to_play.enemy().toInt()).mask & tPawns;
        //std.debug.print("ep attackers 0x{x}\n", .{enPassantAttackers});
        if (@popCount(enPassantAttackers) == 0) {
            return 0;
        }
        

        while (enPassantAttackers > 0) : (enPassantAttackers = bit_set.popLstb(enPassantAttackers)) {
            const move = Move.New(@intCast(@ctz(enPassantAttackers)), position.en_passant_sq, .epCapture);
            const team = position.to_play;
            
            position.makeMove2(move);

            if (!position.isKingInCheck(team, position.notEmpty())) {
            
                position.unmakeMove2(move);
                return @as(u64, 1) << position.en_passant_sq;
            }

            position.unmakeMove2(move);
        }

        return 0;
    }

    return 0;
}

fn generatePawnMoves2(
                    position: *const Position, 
                    moveList: *MoveList, 
                    bitboard: u64, 
                    genInfo: PieceStoreMoveInfo, 
                    enPassantSquare: u64) 
                    void 
{
    var normalPush: u64 = 0;
    var doublePush: u64 = 0;
    var promotions: u64 = 0;
    var offset: i6 = 0;
    var attackSet: u64 = 0;
    var captures: u64 = 0;
    var promotionsWithCapture: u64 = 0;
    const e = position.empty();

    const rank3: u64 = 0xff0000;
    const rank8: u64 = 0xff00000000000000;
    const not_a_file: u64 = 0xfefefefefefefefe;
    const not_h_file: u64 = 0x7f7f7f7f7f7f7f7f;

    const rank6: u64 = 0xff0000000000;
    const rank1: u64 = 0xff;

    if (position.to_play == .white) {
        normalPush = ((bitboard << 8) & e);
        doublePush = ((normalPush & rank3) << 8) & e;

        normalPush &= genInfo.legalSquares;
        doublePush &= genInfo.legalSquares;

        promotions = normalPush & rank8;
        normalPush ^= promotions;
        offset = -8;

        attackSet = (((bitboard << 9) & not_a_file) | ((bitboard << 7) & not_h_file));
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

        attackSet = (((bitboard >> 7) & not_a_file) | ((bitboard >> 9) & not_h_file));
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
        var attackers: u64 = lot.getPawnAttackSet(sq, position.to_play.enemy().toInt()).mask & bitboard;
        while (attackers > 0) : (attackers = bit_set.popLstb(attackers)) {
            moveList.add(Move.New(@intCast(@ctz(attackers)), sq, .capture));
        }
    }

    if ((attackSet & enPassantSquare) > 0) {
        const sq: u6 = position.en_passant_sq;
        var attackers: u64 = lot.getPawnAttackSet(sq, position.to_play.enemy().toInt()).mask & bitboard;
        while (attackers > 0) : (attackers = bit_set.popLstb(attackers)) {
            moveList.add(Move.New(@intCast(@ctz(attackers)), sq, .epCapture));
        }
    }

    while (promotionsWithCapture > 0) : (promotionsWithCapture = bit_set.popLstb(promotionsWithCapture)) {
        const sq: u6 = @intCast(@ctz(promotionsWithCapture));
        var attackers: u64 = lot.getPawnAttackSet(sq, position.to_play.enemy().toInt()).mask & bitboard;
        while (attackers > 0) : (attackers = bit_set.popLstb(attackers)) {
            inline for (0..4) |i| {
                moveList.add(Move.New(@intCast(@ctz(attackers)), sq, @fromBackingInt(@intCast(Move.Flags.toInt(.knightPromotionCapture) + @as(u4, @intCast(i))))));
            }
        }
    }
}

fn generateKingCastleMoves(
                position: *const Position, 
                moveList: *MoveList, 
                kingSquare: u6, 
                enemyAttackSet: u64, 
                team: u64, 
                enemy: u64) 
                void {
    const queenSideCastleMask: u64 = @as(u64, 0xc) << ((kingSquare >> 3) << 3);
    const kingSideCastleMask: u64 = @as(u64, 0x60) << ((kingSquare >> 3) << 3);
    const queenSideCastleMaskB: u64 = (queenSideCastleMask >> @as(u6, 1)) | queenSideCastleMask;

    const castleRights: u2 = @intCast((position.castle_rights >> (@as(u2, @intFromBool(position.to_play == .black)) << 1)) & 0x3);

    const kingSideCastle: bool = (castleRights & 0x1) > 0 and (kingSideCastleMask & (enemyAttackSet | team | enemy)) == 0;
    const queenSideCastle: bool = (castleRights & 0x2) > 0 and (queenSideCastleMask & enemyAttackSet) == 0 and queenSideCastleMaskB & (team | enemy) == 0;

    if (kingSideCastle) {
        moveList.add(Move.New(kingSquare, kingSquare + 2, .kingSideCastle));
    }

    if (queenSideCastle) {
        moveList.add(Move.New(kingSquare, kingSquare - 2, .queenSideCastle));
    }
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
