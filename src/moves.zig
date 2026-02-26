const board = @import("bitboards.zig");
const std = @import("std");

pub const Move = struct {
    pieceBB: u4,
    colorBB: u4,
    captureBB: u4,
    colorCaptureBB: u4,
    from: u6,
    to: u6,
    pState: previousState,
    flags: Flags,

    const previousState = struct{
        epSquare: u6,
        castleRights: u4,
    };

    const Flags = enum(u4){
        quietMove,
        doublePawnPush,
        kingCastle,
        queenCastle,
        capture,
        epCapture,
        bishopPromotion,
        knightPromotion,
        rookPromotion,
        queenPromotion,
    };
};

const MoveList = struct{
    moves: [218]Move,
    count: u8,
};

pub fn generatePseudoLegalMoves(side: board.side) align(64) MoveList{
    var moves: MoveList = .{
        .count = 0,
        .moves = undefined,
    };

    const blackToPlay: u4 = @intFromBool(side == board.side.black);
    const start: u4 = 6 * blackToPlay;
    const end: u4 = 6 + 6 * blackToPlay;

    const team: u64 = board.bitBoards[@intFromEnum(board.pieceBB.white) + blackToPlay];
    const enemy: u64 = board.bitBoards[@intFromEnum(board.pieceBB.black) - blackToPlay];

    const pieces: []u64 = board.bitBoards[start..end];

    generatePawnMoves(&moves, pieces[0], board.empty, enemy, side);
    generateBishopMoves(&moves, pieces[1], team, enemy, side);
    generateKnightMoves(&moves, pieces[2], team, enemy, side);
    generateRookMoves(&moves, pieces[3], team, enemy, side);
    generateQueenMoves(&moves, pieces[4], team, enemy, side);
    generateKingMoves(&moves, pieces[5], team, enemy, side);

    return moves;
}

pub fn generateLegalMoves() align(64) MoveList{
    var moves = generatePseudoLegalMoves(board.toPlay);
    const blackToPlay: u4 = @intFromBool(board.toPlay == board.side.black);
    const king: *u64 = &board.bitBoards[5 + (6 * blackToPlay)];

    var i: u8 = 0;

    while (i < moves.count):(i +%= 1) {
        var move: Move = moves.moves[i];
        makeMove(&move);
        if(isSquareAttacked(king.*, board.toPlay,board.bitBoards[@intFromEnum(board.pieceBB.all)])){ 
            moves.moves[i] = moves.moves[moves.count - 1];
            moves.count -= 1;
            i -%= 1;
        }
        unMakeMove(move);
    }

    return moves;
}

fn generatePawnMoves(moves: *MoveList, bb: u64, empty: u64, enemy: u64, side: board.side) void{
    const whiteToPlay = @intFromBool(side == board.side.white);
    var normalPush: u64 = 0;
    var doublePush: u64 = 0;
    var pieceBB: u4 = undefined;
    var colorBB: u4 = undefined;
    var colorCaptureBB: u4 = undefined;
    var offset: i6 = 0;

    if(whiteToPlay == 1){
        normalPush = (bb << 8 & empty);
        doublePush = (((bb << 8 & empty) & board.rank3) << 8) & empty;
        pieceBB = @intFromEnum(board.pieceBB.wPawn);
        colorBB = @intFromEnum(board.pieceBB.white);
        colorCaptureBB = @intFromEnum(board.pieceBB.black);
        offset = -8;
    }else{
        normalPush = (bb >> 8 & empty);
        doublePush = (((bb >> 8 & empty) & board.rank6) >> 8) & empty;
        pieceBB = @intFromEnum(board.pieceBB.bPawn);
        colorBB = @intFromEnum(board.pieceBB.black);
        colorCaptureBB = @intFromEnum(board.pieceBB.white);
        offset = 8;
    }
    
    while(normalPush > 0): (normalPush &= normalPush - 1){
        const sq: u6 = @intCast(@ctz(normalPush));
        moves.moves[moves.count].to = sq;
        moves.moves[moves.count].from = sq +% @as(u6, @bitCast(offset));
        moves.moves[moves.count].flags = Move.Flags.quietMove;
        moves.moves[moves.count].pieceBB = pieceBB;
        moves.moves[moves.count].colorBB = colorBB;
        moves.moves[moves.count].captureBB = 0;
        moves.moves[moves.count].colorCaptureBB = 0;
        moves.count += 1;
    }

    while(doublePush > 0): (doublePush &= doublePush - 1){
        const sq: u6 = @intCast(@ctz(doublePush));
        moves.moves[moves.count].to = sq;
        moves.moves[moves.count].from = sq +% @as(u6, @bitCast(offset * 2));
        moves.moves[moves.count].flags = Move.Flags.doublePawnPush;
        moves.moves[moves.count].pieceBB = pieceBB;
        moves.moves[moves.count].colorBB = colorBB;
        moves.moves[moves.count].captureBB = 0;
        moves.moves[moves.count].colorCaptureBB = 0;
        moves.count += 1;
    }

    var pawn: u64 = bb;
    const epSquare: u64 =  (@as(u64, 1) << board.enPassant);
    while(pawn > 0): (pawn &= pawn - 1){
        const sq: u6 = @intCast(@ctz(pawn));
        var m: u64 = board.getPawnAtt(sq, ~whiteToPlay) & (enemy | epSquare);
        while(m > 0): (m &= m - 1){
            const nsq: u6 = @intCast(@ctz(m));
            const isEpCapture = (epSquare & (@as(u64, 1) << nsq)) > 0;
            const epCapture: u4 =  if(side == board.side.white) @intFromEnum(board.pieceBB.bPawn) 
                                else @intFromEnum(board.pieceBB.wPawn);
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].flags = if(!isEpCapture) Move.Flags.capture else Move.Flags.epCapture;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = if(!isEpCapture) board.getPieceBB(nsq) else epCapture;
            moves.moves[moves.count].colorCaptureBB = colorCaptureBB;
            moves.count += 1;
        }
    }
}

fn generateKnightMoves(moves: *MoveList, bb: u64, team: u64, enemy: u64, side: board.side) void{
    var knight = bb;
    const whiteToPlay: u4 = @bitCast(-@as(i4, @intFromBool(side == board.side.white)));
    const pieceBB: u4 = (@intFromEnum(board.pieceBB.wKnight) & whiteToPlay) + 
                        (@intFromEnum(board.pieceBB.bKnight) & ~ whiteToPlay);

    const colorBB: u4 = (@intFromEnum(board.pieceBB.white) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.black) & ~whiteToPlay);

    const colorCaptureBB: u4 = (@intFromEnum(board.pieceBB.black) & whiteToPlay) + 
                               (@intFromEnum(board.pieceBB.white) & ~whiteToPlay);

    while(knight > 0): (knight &= knight - 1){
        const sq: u6 = @intCast(@ctz(knight));
        const m = board.getKnightMoves(sq) & ~team;
        var attMoves = m & enemy;
        var quietMoves = m ^ attMoves;
        
        while(quietMoves > 0): (quietMoves &= quietMoves - 1){ // quiet moves
            const nsq: u6 = @intCast(@ctz(quietMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB =  colorBB;
            moves.moves[moves.count].captureBB = 0;
            moves.moves[moves.count].colorCaptureBB = 0;
            moves.moves[moves.count].flags = Move.Flags.quietMove;
            moves.count += 1;
        }

        while(attMoves > 0): (attMoves &= attMoves - 1){    // captures
            const nsq: u6 = @intCast(@ctz(attMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = board.getPieceBB(nsq);
            moves.moves[moves.count].colorCaptureBB = colorCaptureBB;
            moves.moves[moves.count].flags = Move.Flags.capture;
            moves.count += 1;
        }
    }
}

fn generateKingMoves(moves: *MoveList, bb: u64, team: u64, enemy: u64, side: board.side) void{
    const sq: u6 = @intCast(@ctz(bb));
    const enemyAtt = getSideAtt(~@intFromEnum(side), (team | enemy));
    const m = board.getKingMoves(sq) & (~team & ~enemyAtt);
    const castleMask: u64 = @as(u64, 0x6e) << ((sq >> 3) * 8);

    const castleRights: u2 = @intCast((board.castleRights >> (@as(u2, @intFromBool(side == board.side.black)) << 1)) & 0x3);

    const canCastle = !((castleMask & (team | enemy)) > 0) and !((bb & enemy) > 0) and (castleRights > 0);

    _ = canCastle;

    var captureMoves = m & enemy; 
    var quietMoves = m ^ captureMoves;

    const whiteToPlay: u4 = @bitCast(-@as(i4, @intFromBool(side == board.side.white)));
    const pieceBB: u4 = (@intFromEnum(board.pieceBB.wKing) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.bKing) & ~whiteToPlay);

    const colorBB: u4 = (@intFromEnum(board.pieceBB.white) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.black) & ~whiteToPlay);

    const colorCaptureBB: u4 = (@intFromEnum(board.pieceBB.black) & whiteToPlay) + 
                               (@intFromEnum(board.pieceBB.white) & ~whiteToPlay);

    while(quietMoves > 0): (quietMoves &= quietMoves - 1){
        const nsq: u6 = @intCast(@ctz(quietMoves));
        moves.moves[moves.count].from = sq;
        moves.moves[moves.count].to = nsq;
        moves.moves[moves.count].flags = Move.Flags.quietMove;
        moves.moves[moves.count].pieceBB = pieceBB;
        moves.moves[moves.count].colorBB = colorBB;
        moves.moves[moves.count].captureBB = 0;
        moves.moves[moves.count].colorCaptureBB = 0;

        moves.count += 1;
    }

    while(captureMoves > 0): (captureMoves &= captureMoves - 1){
        const nsq: u6 = @intCast(@ctz(captureMoves));
        moves.moves[moves.count].from = sq;
        moves.moves[moves.count].to = nsq;
        moves.moves[moves.count].flags = Move.Flags.capture;
        moves.moves[moves.count].pieceBB = pieceBB;
        moves.moves[moves.count].colorBB = colorBB;
        moves.moves[moves.count].captureBB = board.getPieceBB(nsq);
        moves.moves[moves.count].colorCaptureBB = colorCaptureBB;

        moves.count += 1;
    }
}

fn generateBishopMoves(moves: *MoveList, bb: u64, team: u64, enemy: u64, side: board.side) void{
    const whiteToPlay: u4 = @bitCast(-@as(i4, @intFromBool(side == board.side.white)));
    const pieceBB: u4 = (@intFromEnum(board.pieceBB.wBishop) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.bBishop) & ~whiteToPlay);

    const colorBB: u4 = (@intFromEnum(board.pieceBB.white) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.black) & ~whiteToPlay);

    const colorCaptureBB: u4 = (@intFromEnum(board.pieceBB.black) & whiteToPlay) + 
                               (@intFromEnum(board.pieceBB.white) & ~whiteToPlay);
    var bishop = bb;
    while(bishop > 0): (bishop &= bishop - 1){
        const sq: u6 = @intCast(@ctz(bishop));
        const m = board.getBishopMoves(sq, team | enemy) & ~team;
        var captureMoves = m & enemy; 
        var quietMoves = m ^ captureMoves;

        while(quietMoves > 0): (quietMoves &= quietMoves - 1){
            const nsq: u6 = @intCast(@ctz(quietMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].flags = Move.Flags.quietMove;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = 0;
            moves.moves[moves.count].colorCaptureBB = 0;
            moves.count += 1;
        }

        while(captureMoves > 0): (captureMoves &= captureMoves - 1){
            const nsq: u6 = @intCast(@ctz(captureMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].flags = Move.Flags.capture;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = board.getPieceBB(nsq);
            moves.moves[moves.count].colorCaptureBB = colorCaptureBB;
            moves.count += 1;
        }
    }
}

fn generateRookMoves(moves: *MoveList, bb: u64, team: u64, enemy: u64, side: board.side) void{
    const whiteToPlay: u4 = @bitCast(-@as(i4, @intFromBool(side == board.side.white)));
    const pieceBB: u4 = (@intFromEnum(board.pieceBB.wRook) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.bRook) & ~whiteToPlay);

    const colorBB: u4 = (@intFromEnum(board.pieceBB.white) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.black) & ~whiteToPlay);

    const colorCaptureBB: u4 = (@intFromEnum(board.pieceBB.black) & whiteToPlay) + 
                               (@intFromEnum(board.pieceBB.white) & ~whiteToPlay);

    var rook = bb;
    while(rook > 0): (rook &= rook - 1){
        const sq: u6 = @intCast(@ctz(rook));
        const m = board.getRookMoves(sq, team | enemy) & ~team;
        var captureMoves = m & enemy; 
        var quietMoves = m ^ captureMoves;

        while(quietMoves > 0): (quietMoves &= quietMoves - 1){
            const nsq: u6 = @intCast(@ctz(quietMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].flags = Move.Flags.quietMove;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = 0;
            moves.moves[moves.count].colorCaptureBB = 0;
            moves.count += 1;
        }

        while(captureMoves > 0): (captureMoves &= captureMoves - 1){
            const nsq: u6 = @intCast(@ctz(captureMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].flags = Move.Flags.capture;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = board.getPieceBB(nsq);
            moves.moves[moves.count].colorCaptureBB = colorCaptureBB;
            moves.count += 1;
        }
    }
}

fn generateQueenMoves(moves: *MoveList, bb: u64, team: u64, enemy: u64, side: board.side) void{
    const whiteToPlay: u4 = @bitCast(-@as(i4, @intFromBool(side == board.side.white)));
    const pieceBB: u4 = (@intFromEnum(board.pieceBB.wQueen) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.bQueen) & ~whiteToPlay);

    const colorBB: u4 = (@intFromEnum(board.pieceBB.white) & whiteToPlay) +
                        (@intFromEnum(board.pieceBB.black) & ~whiteToPlay);

    const colorCaptureBB: u4 = (@intFromEnum(board.pieceBB.black) & whiteToPlay) + 
                               (@intFromEnum(board.pieceBB.white) & ~whiteToPlay);
    var queen = bb;
    while(queen > 0): (queen &= queen - 1){
        const sq: u6 = @intCast(@ctz(queen));
        const m = board.getQueenMoves(sq, team | enemy) & ~team;
        var captureMoves = m & enemy; 
        var quietMoves = m ^ captureMoves;

        while(quietMoves > 0): (quietMoves &= quietMoves - 1){
            const nsq: u6 = @intCast(@ctz(quietMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].flags = Move.Flags.quietMove;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = 0;
            moves.moves[moves.count].colorCaptureBB = 0;
            moves.count += 1;
        }

        while(captureMoves > 0): (captureMoves &= captureMoves - 1){
            const nsq: u6 = @intCast(@ctz(captureMoves));

            moves.moves[moves.count].from = sq;
            moves.moves[moves.count].to = nsq;
            moves.moves[moves.count].flags = Move.Flags.capture;
            moves.moves[moves.count].pieceBB = pieceBB;
            moves.moves[moves.count].colorBB = colorBB;
            moves.moves[moves.count].captureBB = board.getPieceBB(nsq);
            moves.moves[moves.count].colorCaptureBB = colorCaptureBB;
            moves.count += 1;
        }
    }
}

pub fn makeMove(move: *Move) void{

    move.pState.castleRights = board.castleRights;
    move.pState.epSquare = board.enPassant;

    const from = @as(u64, 1) << move.from;
    const to = @as(u64, 1) << move.to;

    const fromTo = from | to;

    board.bitBoards[move.pieceBB] ^= fromTo;
    board.bitBoards[move.colorBB] ^= fromTo;

    const isDoublePawnPush: u6 = @bitCast(-@as(i6, @intFromBool(move.flags == Move.Flags.doublePawnPush)));
    const isEnPassant: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.epCapture)));
    
    const offset: i6 = if(board.toPlay == board.side.white) -8 else 8;
    board.enPassant = (move.to +% @as(u6, @bitCast(offset))) & isDoublePawnPush;
    const epCaptureSq: u64 = (@as(u64, 1) << (move.to +% @as(u6, @bitCast(offset)))) & isEnPassant;

    const isCapture: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.capture)));

    board.bitBoards[move.captureBB] ^= (to & isCapture) | epCaptureSq;
    board.bitBoards[move.colorCaptureBB] ^= (to & isCapture) | epCaptureSq;

    board.empty ^= from | (to & ~isCapture) | epCaptureSq;
    board.bitBoards[@intFromEnum(board.pieceBB.all)] ^= from | (to & ~isCapture) | epCaptureSq;

    board.toPlay = if (board.toPlay == board.side.white) board.side.black else board.side.white;
}

pub fn unMakeMove(move: Move) void{
    board.enPassant = move.pState.epSquare;
    board.castleRights = move.pState.castleRights;
    const from = @as(u64, 1) << move.from;
    const to = @as(u64, 1) << move.to;

    const fromTo = from | to;

    board.bitBoards[move.pieceBB] ^= fromTo;
    board.bitBoards[move.colorBB] ^= fromTo;
    
    const isCapture: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.capture)));
    const isEnPassant: u64 = @bitCast(-@as(i64, @intFromBool(move.flags == Move.Flags.epCapture)));
    const offset: i6 = if(board.toPlay == board.side.white) 8 else -8;
    const epSquare = (@as(u64, 1) << (move.to +% @as(u6, @bitCast(offset)))) & isEnPassant;

    board.bitBoards[move.captureBB] ^= (to & isCapture) | epSquare;
    board.bitBoards[move.colorCaptureBB] ^= (to & isCapture) | epSquare;
    board.empty ^= (from | (to & ~isCapture)) | epSquare; 

    board.bitBoards[@intFromEnum(board.pieceBB.all)] ^= (from | (to & ~isCapture)) | epSquare;

    board.toPlay = if (board.toPlay == board.side.white) board.side.black else board.side.white;
}

fn getSideAtt(side: u1, occ: u64) u64{
    
    const start: u4 = 6 * @as(u4, @intFromBool(side == @intFromEnum(board.side.black)));
    const end: u4 = 6 + (6 * @as(u4, @intFromBool(side == @intFromEnum(board.side.black))));

    var attackSet: u64 = 0;

    const pieces = board.bitBoards[start..end];

    const whiteToPlay: u64 = @bitCast(-@as(i64, @intFromBool(side == @intFromEnum(board.side.white))));
    const pawnAttacks = (((pieces[0] << 7 & board.notHFile) | (pieces[0] << 9 & board.notAFile)) & whiteToPlay) +
                             (((pieces[0] >> 9 & board.notHFile) | (pieces[0] >> 7 & board.notAFile)) & ~whiteToPlay);

    attackSet |= pawnAttacks;
    attackSet |= board.getKingMoves(@intCast(@ctz(pieces[5])));

    var bishops: u64 = pieces[1];
    while(bishops > 0): (bishops &= bishops - 1){
        attackSet |= board.getBishopMoves(@intCast(@ctz(bishops)), occ);
    }

    var knights: u64 = pieces[2];
    while(knights > 0): (knights &= knights - 1){
        attackSet |= board.getKnightMoves(@intCast(@ctz(knights)));
    }

    var rooks: u64 = pieces[3];
    while(rooks > 0): (rooks &= rooks - 1){
        attackSet |= board.getRookMoves(@intCast(@ctz(rooks)), occ);
    }

    var queens: u64 = pieces[4];
    while(queens > 0): (queens &= queens - 1){
        attackSet |= board.getQueenMoves(@intCast(@ctz(queens)), occ);
    }

    return attackSet;
}

inline fn countZeroes(bb: u64) u6{
    if(bb < 0){
        return 0;
    }else{
        return @intCast(@ctz(bb));
    }
}


inline fn isSquareAttacked(sq: u64, enemySide: board.side, occ: u64) bool{
    const enemyAtt: u64 = getSideAtt(@intFromEnum(enemySide), occ);
    
    return (sq & enemyAtt) > 0;
}

pub fn perftDivide(depth: u32) void{
    const moves = generateLegalMoves();
    var tot: u64 = 0;

    for(0..moves.count) |i|{
        makeMove(&moves.moves[i]);
        const p = perft(depth - 1);
        std.debug.print("{s}{s}, {} {}: {}\n", .{
            board.getSquareChar(moves.moves[i].from), board.getSquareChar(moves.moves[i].to), 
            moves.moves[i].from, moves.moves[i].to,
            p 
        });
        tot += p;
        unMakeMove(moves.moves[i]);
    }
    std.debug.print("{}\n", .{tot});
}

pub fn perft(depth: u32) u64{
    var nodes: u64 = 0;
    var moves = generateLegalMoves();

    if(depth == 0){
        return @as(u64, 1);
    }else if(depth == 1){
        return moves.count;
    }

    for(0..moves.count) |i|{
        makeMove(&moves.moves[i]);
        nodes += perft(depth - 1);
        unMakeMove(moves.moves[i]);
    }

    //std.debug.print("{}\n", .{depth});
    return nodes;
}
