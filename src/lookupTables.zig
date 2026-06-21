const std = @import("std");
const Board = @import("board.zig");

pub const side = enum(u1) {
    white,
    black,
};

pub const pieceBB = enum(u4) {
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

pub const squares = enum(u8) {
    a1,
    b1,
    c1,
    d1,
    e1,
    f1,
    g1,
    h1,
    a2,
    b2,
    c2,
    d2,
    e2,
    f2,
    g2,
    h2,
    a3,
    b3,
    c3,
    d3,
    e3,
    f3,
    g3,
    h3,
    a4,
    b4,
    c4,
    d4,
    e4,
    f4,
    g4,
    h4,
    a5,
    b5,
    c5,
    d5,
    e5,
    f5,
    g5,
    h5,
    a6,
    b6,
    c6,
    d6,
    e6,
    f6,
    g6,
    h6,
    a7,
    b7,
    c7,
    d7,
    e7,
    f7,
    g7,
    h7,
    a8,
    b8,
    c8,
    d8,
    e8,
    f8,
    g8,
    h8,
};

const mDiagonalShifts: [64]i8 = [_]i8{
    0, -1, -2, -3, -4, -5, -6, -7,
    1, 0,  -1, -2, -3, -4, -5, -6,
    2, 1,  0,  -1, -2, -3, -4, -5,
    3, 2,  1,  0,  -1, -2, -3, -4,
    4, 3,  2,  1,  0,  -1, -2, -3,
    5, 4,  3,  2,  1,  0,  -1, -2,
    6, 5,  4,  3,  2,  1,  0,  -1,
    7, 6,  5,  4,  3,  2,  1,  0,
};

const aDiagonalShifts: [64]i8 = [_]i8{
    -7, -6, -5, -4, -3, -2, -1, 0,
    -6, -5, -4, -3, -2, -1, 0,  1,
    -5, -4, -3, -2, -1, 0,  1,  2,
    -4, -3, -2, -1, 0,  1,  2,  3,
    -3, -2, -1, 0,  1,  2,  3,  4,
    -2, -1, 0,  1,  2,  3,  4,  5,
    -1, 0,  1,  2,  3,  4,  5,  6,
    0,  1,  2,  3,  4,  5,  6,  7,
};

const pawnLookUpTable: [2][64]u64 = initPawnLookUpTable();
const pawnAttLookUpTAble: [2][64]u64 = initPawnAttacksLookUpTable();
const knightLookUpTable: [64]u64 = initKnightLookUpTable();
const kingLookUpTable: [64]u64 = initKingLookUpTable();

pub const bishopMask: [64]u64 = createBishopMask();
pub const rookMask: [64]u64 = createRookMask();

pub const bishopMagicTable: [64][512]u64 = initBishopMoves();
pub const rookMagicTable: [64][4096]u64 = initRookMoves();

pub const bishopMagics: [64]u64 = [_]u64{
    0x0010440100420200,
    0x0290018200860000,
    0x0808018302100200,
    0x00042400912C0000,
    0x0001104001730000,
    0x0000821040500000,
    0x0400480804920200,
    0x02028208008A0800,
    0x0500400409020200,
    0x4000041104330200,
    0x4000040430A20100,
    0x0004040400800000,
    0x0000040420450000,
    0x0C808A0802E80400,
    0x000000A804126000,
    0x0004010288044200,
    0x0008002002D00200,
    0x0442100902040400,
    0x000800C100490200,
    0x080D000804910000,
    0x0001000890401000,
    0x0001010200D10400,
    0x0000804068081800,
    0x0000801908E11000,
    0x0008200040340100,
    0x0010900004770200,
    0x0022020001080200,
    0x0000C04004010200,
    0x0200840000802000,
    0x0008020000C04200,
    0x0002220800411000,
    0x2002018000404800,
    0x6002904000D00200,
    0x0004300404480100,
    0x0884220810290800,
    0x0000042008040100,
    0x2800440400584100,
    0x0010040020C91000,
    0x08080080821B0800,
    0x00018100400E0200,
    0x0004022004121000,
    0x8004044228000200,
    0x0101008040600C00,
    0x3000004201900800,
    0x0010088101C20C00,
    0x0001101100450200,
    0x2024100201442200,
    0x0001020400480900,
    0x0080882402E00000,
    0x06028404028A0800,
    0x00000104012C4000,
    0x0000080304880000,
    0x0040004005070000,
    0x00000410024A0000,
    0x0008083004C60000,
    0x002C040422620000,
    0x1010220210130800,
    0x0000808201352000,
    0x8000000100A80400,
    0x0008018000840400,
    0x2000000010120200,
    0x2120800410463200,
    0x1000440802840C00,
    0x10040C1000D70100,
};

pub const rookMagics: [64]u64 = [_]u64{
    0xa8002c000108020,
    0x6c00049b0002001,
    0x100200010090040,
    0x2480041000800801,
    0x280028004000800,
    0x900410008040022,
    0x280020001001080,
    0x2880002041000080,
    0xa000800080400034,
    0x4808020004000,
    0x2290802004801000,
    0x411000d00100020,
    0x402800800040080,
    0xb000401004208,
    0x2409000100040200,
    0x1002100004082,
    0x22878001e24000,
    0x1090810021004010,
    0x801030040200012,
    0x500808008001000,
    0xa08018014000880,
    0x8000808004000200,
    0x201008080010200,
    0x801020000441091,
    0x800080204005,
    0x1040200040100048,
    0x120200402082,
    0xd14880480100080,
    0x12040280080080,
    0x100040080020080,
    0x9020010080800200,
    0x813241200148449,
    0x491604001800080,
    0x100401000402001,
    0x4820010021001040,
    0x400402202000812,
    0x209009005000802,
    0x810800601800400,
    0x4301083214000150,
    0x204026458e001401,
    0x40204000808000,
    0x8001008040010020,
    0x8410820820420010,
    0x1003001000090020,
    0x804040008008080,
    0x12000810020004,
    0x1000100200040208,
    0x430000a044020001,
    0x280009023410300,
    0xe0100040002240,
    0x200100401700,
    0x2244100408008080,
    0x8000400801980,
    0x2000810040200,
    0x8010100228810400,
    0x2000009044210200,
    0x4080008040102101,
    0x40002080411d01,
    0x2005524060000901,
    0x502001008400422,
    0x489a000810200402,
    0x1004400080a13,
    0x4000011008020084,
    0x26002114058042,
};

pub const bishopShifts: [64]u6 = [_]u6{
    58, 59, 59, 59, 59, 59, 59, 58,
    59, 59, 59, 59, 59, 59, 59, 59,
    59, 59, 57, 57, 57, 57, 59, 59,
    59, 59, 57, 55, 55, 57, 59, 59,
    59, 59, 57, 55, 55, 57, 59, 59,
    59, 59, 57, 57, 57, 57, 59, 59,
    59, 59, 59, 59, 59, 59, 59, 59,
    58, 59, 59, 59, 59, 59, 59, 58,
};

pub const rookShifts: [64]u6 = [_]u6{ 52, 53, 53, 53, 53, 53, 53, 52, 53, 54, 54, 54, 54, 54, 54, 53, 53, 54, 54, 54, 54, 54, 54, 53, 53, 54, 54, 54, 54, 54, 54, 53, 53, 54, 54, 54, 54, 54, 54, 53, 53, 54, 54, 54, 54, 54, 54, 53, 53, 54, 54, 54, 54, 54, 54, 53, 52, 53, 53, 53, 53, 53, 53, 52 };

pub inline fn popLstb(bb: u64) u64 {
    return bb & (bb - 1);
}

pub inline fn setBit(bb: u64, square: u8) u64 {
    return bb | (@as(u64, 1) << square);
}

pub inline fn popBit(bb: u64, square: u8) u64 {
    return bb & (bb ^ (@as(u64, 1) << square));
}

pub fn generateRookAttacks(square: u8, blokers: u64) u64 {
    @setEvalBranchQuota(2260000);
    var res: u64 = 0;

    const rank: u3 = @intCast(square >> 3);
    const file: u3 = @intCast(square & 7);

    var r1 = @addWithOverflow(rank, 1);
    var r2 = @addWithOverflow(file, 1);
    var r3 = @subWithOverflow(rank, 1);
    var r4 = @subWithOverflow(file, 1);

    while (r1[1] != 1) { // rank up
        if (blokers & ((@as(u64, 1) << @intCast(8 * @as(u8, r1[0]))) << file) > 0) {
            res |= ((@as(u64, 1) << @intCast(8 * @as(u8, r1[0]))) << file);
            break;
        }

        res |= ((@as(u64, 1) << @intCast(8 * @as(u8, r1[0]))) << file);
        r1 = @addWithOverflow(r1[0], 1);
    }

    while (r2[1] != 1) { // file right
        if (blokers & (@as(u64, 1) << r2[0]) << @intCast(8 * @as(u8, rank)) > 0) {
            res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
            break;
        }

        res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
        r2 = @addWithOverflow(r2[0], 1);
    }

    while (r3[1] != 1) { // rank down
        if ((blokers & (((@as(u64, 1)) << @intCast(8 * @as(u8, r3[0]))) << file)) > 0) {
            res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;
            break;
        }
        //std.log.debug("r3 {}\n", .{r3[0]});
        res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;

        r3 = @subWithOverflow(r3[0], 1);
    }

    while (r4[1] != 1) { // file left
        const cPos: u64 = (@as(u64, 1) << r4[0]) << @intCast(8 * @as(u64, rank));

        if ((blokers & cPos) > 0) {
            res |= cPos;
            break;
        }

        res |= cPos;
        r4 = @subWithOverflow(r4[0], 1);
    }

    return res;
}

pub fn generateBishopAttacks(square: u8, blokers: u64) u64 {
    @setEvalBranchQuota(260000);
    var res: u64 = 0;

    const rank: u3 = @intCast(square >> 3);
    const file: u3 = @intCast(square & 7);

    var r11 = @addWithOverflow(rank, 1); // 1 rank
    var r12 = @addWithOverflow(file, 1); // 2 file

    while (r11[1] != 1 and r12[1] != 1) {
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r11[0])) << r12[0];

        if (blokers & nPos > 0) {
            res |= nPos;
            break;
        }

        res |= nPos;
        r11 = @addWithOverflow(r11[0], 1);
        r12 = @addWithOverflow(r12[0], 1);
    }

    var r21 = @subWithOverflow(rank, 1);
    var r22 = @addWithOverflow(file, 1);

    while (r21[1] != 1 and r22[1] != 1) {
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r21[0])) << r22[0];

        if (blokers & nPos > 0) {
            res |= nPos;
            break;
        }

        res |= nPos;
        r21 = @subWithOverflow(r21[0], 1);
        r22 = @addWithOverflow(r22[0], 1);
    }

    var r31 = @subWithOverflow(rank, 1);
    var r32 = @subWithOverflow(file, 1);

    while (r31[1] != 1 and r32[1] != 1) {
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r31[0])) << r32[0];

        if (blokers & nPos > 0) {
            res |= nPos;
            break;
        }

        res |= nPos;
        r31 = @subWithOverflow(r31[0], 1);
        r32 = @subWithOverflow(r32[0], 1);
    }

    var r41 = @addWithOverflow(rank, 1);
    var r42 = @subWithOverflow(file, 1);

    while (r41[1] != 1 and r42[1] != 1) {
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r41[0])) << r42[0];

        if (blokers & nPos > 0) {
            res |= nPos;
            break;
        }

        res |= nPos;
        r41 = @addWithOverflow(r41[0], 1);
        r42 = @subWithOverflow(r42[0], 1);
    }

    return res;
}

fn createBishopMask() [64]u64 {
    var masks: [64]u64 = undefined;
    var i: u8 = 0;
    for (0..64) |_| {
        masks[i] = 0;

        if (mDiagonalShifts[i] >= 0) {
            masks[i] |= Board.mDiagonal << @intCast(8 * mDiagonalShifts[i]);
        } else if (mDiagonalShifts[i] < 0) {
            masks[i] |= Board.mDiagonal >> @intCast(8 * (-mDiagonalShifts[i]));
        }

        if (aDiagonalShifts[i] >= 0) {
            masks[i] |= Board.aDiagonal << @intCast(8 * aDiagonalShifts[i]);
        } else if (aDiagonalShifts[i] < 0) {
            masks[i] |= Board.aDiagonal >> @intCast(8 * (-aDiagonalShifts[i]));
        }

        masks[i] ^= @as(u64, 1) << @intCast(i);
        masks[i] &= Board.notAFile & Board.notHFile & (~Board.rank1 & ~Board.rank8);
        i += 1;
    }

    return masks;
}

fn createRookMask() [64]u64 {
    var masks: [64]u64 = undefined;
    for (0..64) |i| {
        const rank: u3 = @intCast(i >> 3);
        const file: u3 = @intCast(i & 7);
        const mask: u64 = (((Board.rank1 << (@as(u6, rank) * 8)) & (Board.notAFile & Board.notHFile)) | ((Board.aFile << file) & ~(Board.rank1 | Board.rank8)));
        masks[i] = mask & (mask ^ (@as(u64, 1) << @intCast(i)));
    }
    return masks;
}

fn initPawnLookUpTable() [2][64]u64 {
    var moves: [2][64]u64 = undefined;
    for (0..64) |i| {
        const pos: u64 = @as(u64, 1) << @intCast(i);
        moves[0][i] = (pos << 8) | ((pos & Board.rank2) << 16); // WHITE
        moves[1][i] = (pos >> 8) | ((pos & Board.rank7) >> 16); // BLACK
    }
    return moves;
}

fn initKnightLookUpTable() [64]u64 {
    var masks: [64]u64 = undefined;
    for (0..64) |i| {
        const pos: u64 = @as(u64, 1) << @intCast(i);
        masks[i] = ((pos << 17) & Board.notAFile) |
            ((pos << 15) & Board.notHFile) |
            ((pos << 10) & Board.notABFile) |
            ((pos << 6) & Board.notHGFile) |
            ((pos >> 10) & Board.notHGFile) |
            ((pos >> 17) & Board.notHFile) |
            ((pos >> 15) & Board.notAFile) |
            ((pos >> 6) & Board.notABFile);
    }
    return masks;
}

fn initPawnAttacksLookUpTable() [2][64]u64 {
    var att: [2][64]u64 = undefined;
    for (0..64) |i| {
        const pos: u64 = @as(u64, 1) << @intCast(i);
        att[0][i] = (pos << 9 & Board.notAFile) | (pos << 7 & Board.notHFile); // WHITE
        att[1][i] = (pos >> 7 & Board.notAFile) | (pos >> 9 & Board.notHFile); // BLACK
    }
    return att;
}

fn initKingLookUpTable() [64]u64 {
    var masks: [64]u64 = undefined;
    for (0..64) |i| {
        const pos: u64 = @as(u64, 1) << @intCast(i);
        const sides: u64 = ((pos << 1) & Board.notAFile) | ((pos >> 1) & Board.notHFile);
        masks[i] = ((sides | pos) << 8) | ((sides | pos) >> 8) | sides;
    }
    return masks;
}

fn initBishopMoves() [64][512]u64 {
    var masks: [64][512]u64 = undefined;

    var i: u7 = 0;
    //std.debug.print("bishop magics\n", .{});
    for (0..64) |_| {
        //const magic = findBishopMagic(i);
        //std.debug.print("0x{X}\n", .{magic});
        const bits: u7 = @popCount(bishopMask[i]);
        const n = @as(u64, 1) << @intCast(bits);
        var subset: u64 = 0;
        var j: u16 = 0;

        while (j < n) {
            const key = (bishopMagics[i] *% subset) >> bishopShifts[i];

            masks[i][key] = generateBishopAttacks(i, subset);

            subset = (subset -% bishopMask[i]) & bishopMask[i];
            j += 1;
        }

        i += 1;
    }

    return masks;
}

fn initRookMoves() [64][4096]u64 {
    @setEvalBranchQuota(226000);

    var masks: [64][4096]u64 = undefined;

    var i: u7 = 0;

    for (0..64) |_| {
        //const magic = findRookMagic(i);
        //std.debug.print("0x{X}\n", .{magic});
        const bits: u7 = @popCount(rookMask[i]);
        const n = @as(u64, 1) << @intCast(bits);
        //rookMagics[i] = magic;
        var subset: u64 = 0;
        var j: u16 = 0;

        while (j < n) {
            const key = (rookMagics[i] *% subset) >> rookShifts[i];

            masks[i][key] = generateRookAttacks(i, subset);

            subset = (subset -% rookMask[i]) & rookMask[i];
            j += 1;
        }

        i += 1;
    }

    return masks;
}

pub inline fn getBishopMask(sq: u6) u64 {
    var mask: u64 = 0;
    if (mDiagonalShifts[sq] >= 0) {
        mask |= Board.mDiagonal << @intCast(8 * mDiagonalShifts[sq]);
    } else if (mDiagonalShifts[sq] < 0) {
        mask |= Board.mDiagonal >> @intCast(8 * (-mDiagonalShifts[sq]));
    }

    if (aDiagonalShifts[sq] >= 0) {
        mask |= Board.aDiagonal << @intCast(8 * aDiagonalShifts[sq]);
    } else if (aDiagonalShifts[sq] < 0) {
        mask |= Board.aDiagonal >> @intCast(8 * (-aDiagonalShifts[sq]));
    }

    mask ^= @as(u64, 1) << sq;

    return mask;
}

pub inline fn getRookMask(sq: u6) u64 {
    const rank: u3 = @intCast(sq >> 3);
    const file: u3 = @intCast(sq & 7);
    const mask: u64 = (Board.rank1 << (@as(u6, rank) * 8)) | (Board.aFile << file);
    return mask ^ (@as(u64, 1) << sq);
}

pub inline fn getRookMoves(sq: u8, occ: u64) u64 {
    var key = occ & rookMask[sq];
    key *%= rookMagics[sq];
    key >>= rookShifts[sq];
    return rookMagicTable[sq][key];
}

pub inline fn getBishopMoves(sq: u8, occ: u64) u64 {
    var key = occ & bishopMask[sq];
    key *%= bishopMagics[sq];
    key >>= bishopShifts[sq];
    return bishopMagicTable[sq][key];
}

pub inline fn getPawnMoves(sq: u8, color: u1) u64 {
    return pawnLookUpTable[color][sq];
}

pub inline fn getPawnAtt(sq: u8, color: u1) u64 {
    return pawnAttLookUpTAble[color][sq];
}

pub inline fn getKnightMoves(sq: u8) u64 {
    return knightLookUpTable[sq];
}

pub inline fn getKingMoves(sq: u8) u64 {
    return kingLookUpTable[sq];
}

pub inline fn getQueenMoves(sq: u8, occ: u64) u64 {
    return getBishopMoves(sq, occ) | getRookMoves(sq, occ);
}




test "rookMagic" {
    var sq: u8 = 0;
    for(0..64) |_|{
        const n: u64 = @as(u64, 1) << @intCast(@popCount(rookMask[sq]));

        var j: u32 = 0;
        
        var subset: u64 = 0;

        j = 0;
        while(j < n){
            const key = (rookMagics[sq] *% subset) >> rookShifts[sq];
            const att = generateRookAttacks(sq, subset);

            if(rookMagicTable[sq][key] != att){
                std.debug.print("0x{x}\n", .{rookMagics[sq]});
                try std.testing.expect(rookMagicTable[sq][key] == att);
            }

            subset = (subset -% rookMask[sq]) & rookMask[sq];
            j += 1;
        }
        sq += 1;
    }
}

test "bishopMagic"{
    var sq: u8 = 0;
    for(0..64) |_|{
        const n: u64 = @as(u64, 1) << @intCast(@popCount(bishopMask[sq]));

        var j: u32 = 0;
        
        var subset: u64 = 0;

        j = 0;
        while(j < n){
            const key = (bishopMagics[sq] *% subset) >> bishopShifts[sq];
            const att = generateBishopAttacks(sq, subset);

            if(bishopMagicTable[sq][key] != att){
                std.debug.print("0x{x}\n", .{bishopMagics[sq]});
                break;
            }

            subset = (subset -% bishopMask[sq]) & bishopMask[sq];
            j += 1;
        }
        sq += 1;
    }
}

