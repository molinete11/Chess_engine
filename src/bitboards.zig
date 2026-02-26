const std = @import("std");
const expect = std.testing.expect;


pub var bitBoards: [15]u64 = undefined;

pub var toPlay: side = undefined;

pub var castleRights: u4 = undefined; // 1 bit white king side castle, 2 bit white queen side castle
                                      // 3 bit black king side castle, 4 bit black queen side castle

pub var empty: u64 = 0;

pub var enPassant: u6 = 0;

pub const side = enum(u1){
    white,
    black,
};

pub const pieceBB = enum(u4){
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

pub const squares = enum(u8){
    a1, b1, c1, d1, e1, f1, g1, h1, 
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8,
};

pub const squaresChar: [64][2] u8 = [64][2] u8{
    [2]u8{'a', '1'},[2]u8{'b', '1'},[2]u8{'c', '1'},[2]u8{'d', '1'},[2]u8{'e', '1'},[2]u8{'f', '1'},[2]u8{'g', '1'},[2]u8{'h', '1'},
    [2]u8{'a', '2'},[2]u8{'b', '2'},[2]u8{'c', '2'},[2]u8{'d', '2'},[2]u8{'e', '2'},[2]u8{'f', '2'},[2]u8{'g', '2'},[2]u8{'h', '2'},
    [2]u8{'a', '3'},[2]u8{'b', '3'},[2]u8{'c', '3'},[2]u8{'d', '3'},[2]u8{'e', '3'},[2]u8{'f', '3'},[2]u8{'g', '3'},[2]u8{'h', '3'},
    [2]u8{'a', '4'},[2]u8{'b', '4'},[2]u8{'c', '4'},[2]u8{'d', '4'},[2]u8{'e', '4'},[2]u8{'f', '4'},[2]u8{'g', '4'},[2]u8{'h', '4'},
    [2]u8{'a', '5'},[2]u8{'b', '5'},[2]u8{'c', '5'},[2]u8{'d', '5'},[2]u8{'e', '5'},[2]u8{'f', '5'},[2]u8{'g', '5'},[2]u8{'h', '5'},
    [2]u8{'a', '6'},[2]u8{'b', '6'},[2]u8{'c', '6'},[2]u8{'d', '6'},[2]u8{'e', '6'},[2]u8{'f', '6'},[2]u8{'g', '6'},[2]u8{'h', '6'},
    [2]u8{'a', '7'},[2]u8{'b', '7'},[2]u8{'c', '7'},[2]u8{'d', '7'},[2]u8{'e', '7'},[2]u8{'f', '7'},[2]u8{'g', '7'},[2]u8{'h', '7'},
    [2]u8{'a', '8'},[2]u8{'b', '8'},[2]u8{'c', '8'},[2]u8{'d', '8'},[2]u8{'e', '8'},[2]u8{'f', '8'},[2]u8{'g', '8'},[2]u8{'h', '8'},
};

const mDiagonalShifts: [64]i8 = [_]i8{
    0,-1,-2,-3,-4,-5,-6,-7,
    1, 0,-1,-2,-3,-4,-5,-6,
    2, 1, 0,-1,-2,-3,-4,-5,
    3, 2, 1, 0,-1,-2,-3,-4,
    4, 3, 2, 1, 0,-1,-2,-3,
    5, 4, 3, 2, 1, 0,-1,-2,
    6, 5, 4, 3, 2, 1, 0,-1,
    7, 6, 5, 4, 3, 2, 1, 0,
};

const aDiagonalShifts: [64]i8 = [_]i8{
   -7,-6,-5,-4,-3,-2,-1, 0,
   -6,-5,-4,-3,-2,-1, 0, 1,
   -5,-4,-3,-2,-1, 0, 1, 2,
   -4,-3,-2,-1, 0, 1, 2, 3,
   -3,-2,-1, 0, 1, 2, 3, 4,
   -2,-1, 0, 1, 2, 3, 4, 5,
   -1, 0, 1, 2, 3, 4, 5, 6,
    0, 1, 2, 3, 4, 5, 6, 7,
};

pub const notAFile: u64 = 0xfefefefefefefefe;
pub const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
pub const notABFile: u64 = 0xfcfcfcfcfcfcfcfc;
pub const notHGFile: u64 = 0x3f3f3f3f3f3f3f3f;
pub const aFile: u64 = 0x0101010101010101;
pub const rank1: u64 = 0x00000000000000FF;
pub const rank2: u64 = 0x000000000000FF00;
pub const rank3: u64 = 0x0000000000FF0000;
pub const rank4: u64 = 0x00000000FF000000;
pub const rank5: u64 = 0x000000FF00000000;
pub const rank6: u64 = 0x0000FF0000000000;
pub const rank7: u64 = 0x00FF000000000000;
pub const rank8: u64 = 0xFF00000000000000;

const mDiagonal: u64 = 0x8040201008040201;
const aDiagonal: u64 = 0x102040810204080;

const pawnLookUpTable : [2][64]u64 = initPawnLookUpTable();
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

pub const rookShifts: [64]u6 = [_]u6{
    52, 53, 53, 53, 53, 53, 53, 52,
    53, 54, 54, 54, 54, 54, 54, 53,
    53, 54, 54, 54, 54, 54, 54, 53,
    53, 54, 54, 54, 54, 54, 54, 53,
    53, 54, 54, 54, 54, 54, 54, 53,
    53, 54, 54, 54, 54, 54, 54, 53,
    53, 54, 54, 54, 54, 54, 54, 53,
    52, 53, 53, 53, 53, 53, 53, 52
};

pub fn random64Bit() u64{
    var seed: u64 = undefined;
    std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
    var prng = std.Random.DefaultPrng.init(seed);

    const r1 = prng.random().int(u64) & 0xFFFF;
    const r2 = prng.random().int(u64) & 0xFFFF;
    const r3 = prng.random().int(u64) & 0xFFFF;
    const r4 = prng.random().int(u64) & 0xFFFF;

    return (r1 << 48) | (r2 << 32) | (r3 << 16) | (r4 << 8);
}

pub fn randomWithFewerBytes() u64{
    return random64Bit() & random64Bit() & random64Bit() & random64Bit();
}

pub inline fn popLstb(bb : u64) u64{
    return bb & (bb - 1);
}

pub inline fn setBit(bb : u64, square : u8) u64{
    return bb | (@as(u64, 1) << square);
}

pub inline fn popBit(bb : u64, square : u8) u64{
    return bb & (bb ^ (@as(u64, 1) << square));
}

pub fn generateRookAttacks(square : u8, blokers : u64) u64{
    @setEvalBranchQuota(2260000);
    var res : u64 = 0;

    const rank : u3 = @intCast(square >> 3);
    const file : u3 = @intCast(square & 7);
    
    var r1 = @addWithOverflow(rank, 1);
    var r2 = @addWithOverflow(file, 1);
    var r3 = @subWithOverflow(rank, 1);
    var r4 = @subWithOverflow(file, 1);

    while(r1[1] != 1) {  // rank up
        if(blokers & ((@as(u64, 1) << @intCast(8 * @as(u8, r1[0]))) << file) > 0){
            res |=( (@as(u64, 1) << @intCast( 8 * @as(u8, r1[0]) )) << file ); 
            break;
        }
        
        res |=( (@as(u64, 1) << @intCast( 8 * @as(u8, r1[0]) )) << file );
        r1 = @addWithOverflow(r1[0], 1);
    }

    while(r2[1] != 1){  // file right
        if(blokers & (@as(u64, 1) << r2[0]) << @intCast(8 * @as(u8, rank)) > 0){
            res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
            break;
        }

        res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
        r2 = @addWithOverflow(r2[0], 1);
    }


    while(r3[1] != 1){ // rank down
        if((blokers & (((@as(u64, 1)) << @intCast(8 * @as(u8, r3[0]))) << file) ) > 0){
            res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;
            break;
        }
        //std.log.debug("r3 {}\n", .{r3[0]});
        res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;
        
        r3 = @subWithOverflow(r3[0], 1);
    }

    while(r4[1] != 1){   // file left
        const cPos : u64 = (@as(u64, 1) << r4[0]) << @intCast(8 * @as(u64, rank));

        if((blokers & cPos) > 0){
            res |= cPos;
            break;
        }

        res |= cPos;
        r4 = @subWithOverflow(r4[0], 1);
    }

    return res;
}

pub fn generateBishopAttacks(square : u8, blokers : u64) u64{
    @setEvalBranchQuota(260000);
    var res : u64 = 0;

    const rank : u3 = @intCast(square >> 3);
    const file : u3 = @intCast(square & 7);
    
    var r11 = @addWithOverflow(rank, 1); // 1 rank
    var r12 = @addWithOverflow(file, 1); // 2 file

    while(r11[1] != 1 and r12[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r11[0])) << r12[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r11 = @addWithOverflow(r11[0], 1);
        r12 = @addWithOverflow(r12[0], 1);
    }

    var r21 = @subWithOverflow(rank, 1);
    var r22 = @addWithOverflow(file, 1);

    while(r21[1] != 1 and r22[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r21[0])) << r22[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r21 = @subWithOverflow(r21[0], 1);
        r22 = @addWithOverflow(r22[0], 1);
    }

    var r31 = @subWithOverflow(rank, 1);
    var r32 = @subWithOverflow(file, 1);

    while(r31[1] != 1 and r32[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r31[0])) << r32[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r31 = @subWithOverflow(r31[0], 1);
        r32 = @subWithOverflow(r32[0], 1);
    }

    var r41 = @addWithOverflow(rank, 1);
    var r42 = @subWithOverflow(file, 1);

    while(r41[1] != 1 and r42[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r41[0])) << r42[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r41 = @addWithOverflow(r41[0], 1);
        r42 = @subWithOverflow(r42[0], 1);
    }

    return res;
}

pub fn findBishopMagic(sq: u8) u64{
    const n: u64 = @as(u64, 1) << @intCast(@popCount(bishopMask[sq]));

    var j: u32 = 0;

    var used: [4096]u64 = undefined;
    var blockers: [4096]u64 = undefined;
    
    var subset: u64 = 0;
    while(j < n): (j += 1){
        blockers[j] = subset;
        subset = (subset -% bishopMask[sq]) & bishopMask[sq];
    }

    while(true){
        var fail: bool = false;
        j = 0;
        const magic = randomWithFewerBytes();
        for(0..n) |k|{
            used[k] = 0;
        }

        while(!fail and j < n){
            const key = (magic *% blockers[j]) >> bishopShifts[sq];
            const att = generateRookAttacks(sq, blockers[j]);

            if(used[key] == 0){
                used[key] = att;
            }else if(used[key] != att){
                fail = true;
                break;
            }

            j += 1;
        }

        if(!fail){
            return magic;
        }
    }

    return 1;
}

pub fn findRookMagic(sq: u8) u64{
    const n: u64 = @as(u64, 1) << @intCast(@popCount(rookMask[sq]));

    var j: u32 = 0;
    const tries = 1000000;
    var i: u32 = 0;

    var used: [4096]u64 = undefined;
    var blockers: [4096]u64 = undefined;
    
    var subset: u64 = 0;
    while(j < n): (j += 1){
        blockers[j] = subset;
        subset = (subset -% rookMask[sq]) & rookMask[sq];
    }

    while(i < tries){
        var fail: bool = false;
        j = 0;
        const magic = randomWithFewerBytes();
        for(0..n) |k|{
            used[k] = 0;
        }

        while(!fail and j < n){
            const key = (magic *% blockers[j]) >> rookShifts[sq];
            const att = generateRookAttacks(sq, blockers[j]);

            if(used[key] == 0){
                used[key] = att;
            }else if(used[key] != att){
                fail = true;
                break;
            }

            j += 1;
        }

        if(!fail){
            return magic;
        }
        i += 1;
    }

    return 1;
}

fn createBishopMask() [64]u64{
    var masks: [64]u64 = undefined;
    var i: u8 = 0;
    for(0..64) |_|{
        masks[i] = 0;

        if(mDiagonalShifts[i] >= 0){
            masks[i] |= mDiagonal << @intCast(8 * mDiagonalShifts[i]);
        }else if(mDiagonalShifts[i] < 0){
            masks[i] |= mDiagonal >> @intCast(8 * (-mDiagonalShifts[i]));
        }

        if(aDiagonalShifts[i] >= 0){
            masks[i] |= aDiagonal << @intCast(8 * aDiagonalShifts[i]);
        }else if(aDiagonalShifts[i] < 0){
            masks[i] |= aDiagonal >> @intCast(8 * (-aDiagonalShifts[i]));
        }

        masks[i] ^= @as(u64, 1) << @intCast(i);
        masks[i] &= notAFile & notHFile & (~rank1 & ~rank8);
        i += 1;
    }   

    return masks;
}

fn createRookMask() [64]u64{
    var masks : [64]u64 = undefined;
    for(0..64) |i|{
        const rank: u3 = @intCast(i >> 3);
        const file: u3 = @intCast(i & 7);
        const mask : u64 = (((rank1 << (@as(u6, rank) * 8)) & (notAFile & notHFile)) 
                            | ((aFile << file) & ~(rank1 | rank8)));
        masks[i] = mask & (mask ^ (@as(u64, 1) << @intCast(i)));
    }
    return masks;
}

fn initPawnLookUpTable() [2][64]u64{
    var moves: [2][64]u64 = undefined;
    for(0..64) |i | {
        const pos : u64 = @as(u64, 1) << @intCast(i);
        moves[0][i] = (pos << 8) | ((pos & rank2) << 16); // WHITE
        moves[1][i] = (pos >> 8) | ((pos & rank7) >> 16); // BLACK
    }
    return moves;
}

fn initKnightLookUpTable() [64]u64{
    var masks: [64]u64 = undefined;
    for(0..64) |i|{
        const pos : u64 =  @as(u64, 1) << @intCast(i);
        masks[i] = ((pos << 17) & notAFile) | 
                             ((pos << 15) & notHFile) | 
                             ((pos << 10) & notABFile) | 
                             ((pos << 6) & notHGFile) | 
                             ((pos >> 10) & notHGFile) | 
                             ((pos >> 17) & notHFile) | 
                             ((pos >> 15) & notAFile) | 
                             ((pos >> 6) & notABFile);
    }
    return masks;
}

fn initPawnAttacksLookUpTable() [2][64]u64{
    var att: [2][64]u64 = undefined;
    for(0..64) |i | {
        const pos : u64 = @as(u64, 1) << @intCast(i);
        att[0][i] = (pos << 9 & notAFile ) | (pos << 7 & notHFile); // WHITE
        att[1][i] = (pos >> 7 & notAFile) | (pos >> 9 & notHFile); // BLACK
    }
    return att;
}

fn initKingLookUpTable() [64]u64{
    var masks: [64]u64 = undefined;
    for(0..64) |i|{
        const pos : u64 = @as(u64, 1) << @intCast(i);
        const sides : u64 = ((pos << 1) & notAFile) | ((pos >> 1) & notHFile);
        masks[i] = ((sides | pos) << 8) | ((sides | pos) >> 8) | sides;
    }
    return masks;
}

fn initBishopMoves() [64][512]u64{

    var masks: [64][512]u64 = undefined;

    var i: u7 = 0;
    //std.debug.print("bishop magics\n", .{});
    for(0..64) |_|{
        //const magic = findBishopMagic(i);
        //std.debug.print("0x{X}\n", .{magic});
        const bits: u7 = @popCount(bishopMask[i]);
        const n = @as(u64, 1) << @intCast(bits);
        var subset: u64 = 0;
        var j: u16 = 0;

        while(j < n){
            const key = (bishopMagics[i] *% subset) >> bishopShifts[i];

            masks[i][key] = generateBishopAttacks(i, subset);

            subset = (subset -% bishopMask[i]) & bishopMask[i];
            j += 1;
        }

        i += 1; 
    }

    return masks;
}

pub fn initRookMoves() [64][4096]u64 {

    @setEvalBranchQuota(226000);

    var masks: [64][4096]u64 = undefined;

    var i: u7 = 0;

    for(0..64) |_|{
        //const magic = findRookMagic(i);
        //std.debug.print("0x{X}\n", .{magic});
        const bits: u7 = @popCount(rookMask[i]);
        const n = @as(u64, 1) << @intCast(bits);
        //rookMagics[i] = magic;
        var subset: u64 = 0;
        var j: u16 = 0;

        while(j < n){
            const key = (rookMagics[i] *% subset) >> rookShifts[i];
            
            masks[i][key] = generateRookAttacks(i, subset);
             
            subset = (subset -% rookMask[i]) & rookMask[i];
            j += 1;
        }

        i += 1;
    }

    return masks;
}

pub inline fn getRookMoves(sq : u8, occ : u64) u64{
    var key = occ & rookMask[sq];
    key *%= rookMagics[sq];
    key >>= rookShifts[sq];
    return rookMagicTable[sq][key];
}

pub inline fn getBishopMoves(sq: u8, occ: u64) u64{
    var key = occ & bishopMask[sq];
    key *%= bishopMagics[sq];
    key >>= bishopShifts[sq];
    return bishopMagicTable[sq][key];
}

pub inline fn getPawnMoves(sq: u8, sideToPlay: u1) u64{
    return pawnLookUpTable[sideToPlay][sq]; 
}

pub inline fn getPawnAtt(sq: u8, sideToPlay: u1) u64{
    return pawnAttLookUpTAble[sideToPlay][sq];
}

pub inline fn getKnightMoves(sq: u8) u64{
    return knightLookUpTable[sq];
}

pub inline fn getKingMoves(sq: u8) u64{
    return kingLookUpTable[sq];
}

pub inline fn getQueenMoves(sq: u8, occ: u64) u64{
    return getBishopMoves(sq, occ) | getRookMoves(sq, occ);
}

pub fn getPieceBB(sq: u8) u4{
    const pos = @as(u64, 1) << @intCast(sq);

    const wPawn: u4 =  @bitCast(-@as(i4, @intFromBool((bitBoards[0] & pos) > 0)));
    const wBishop: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[1] & pos) > 0)));
    const wKnight: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[2] & pos) > 0)));
    const wRook: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[3] & pos) > 0)));
    const wQueen: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[4] & pos) > 0)));
    const wKing: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[5] & pos) > 0)));

    const bPawn: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[6] & pos) > 0)));
    const bBishop: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[7] & pos) > 0)));
    const bKnight: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[8] & pos) > 0)));
    const bRook: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[9] & pos) > 0)));
    const bQueen: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[10] & pos) > 0)));
    const bKing: u4 = @bitCast(-@as(i4, @intFromBool((bitBoards[11] & pos) > 0)));

    return (@intFromEnum(pieceBB.wPawn) & wPawn) +
           (@intFromEnum(pieceBB.wBishop) & wBishop) +
           (@intFromEnum(pieceBB.wKnight) & wKnight) +
           (@intFromEnum(pieceBB.wRook) & wRook) +
           (@intFromEnum(pieceBB.wQueen) & wQueen) +
           (@intFromEnum(pieceBB.wKing) & wKing) + 
           (@intFromEnum(pieceBB.bPawn) & bPawn) +
           (@intFromEnum(pieceBB.bBishop) & bBishop) +
           (@intFromEnum(pieceBB.bKnight) & bKnight) +
           (@intFromEnum(pieceBB.bRook) & bRook) +
           (@intFromEnum(pieceBB.bQueen) & bQueen) +
           (@intFromEnum(pieceBB.bKing) & bKing);
}

pub fn initStartingPos() void{
    castleRights = 0xF;
    
    toPlay = side.white;
    bitBoards[@intFromEnum(pieceBB.wPawn)] =  0x000000000000ff00;
    bitBoards[@intFromEnum(pieceBB.wBishop)] = 0x0000000000000024;
    bitBoards[@intFromEnum(pieceBB.wKnight)] = 0x0000000000000042;
    bitBoards[@intFromEnum(pieceBB.wRook)] = 0x0000000000000081;
    bitBoards[@intFromEnum(pieceBB.wQueen)] = 0x0000000000000008;
    bitBoards[@intFromEnum(pieceBB.wKing)] = 0x0000000000000010;

    bitBoards[@intFromEnum(pieceBB.bPawn)] =  0x00ff000000000000;
    bitBoards[@intFromEnum(pieceBB.bBishop)] = 0x2400000000000000;
    bitBoards[@intFromEnum(pieceBB.bKnight)] = 0x4200000000000000;
    bitBoards[@intFromEnum(pieceBB.bRook)] = 0x8100000000000000;
    bitBoards[@intFromEnum(pieceBB.bQueen)] = 0x0800000000000000;
    bitBoards[@intFromEnum(pieceBB.bKing)] = 0x1000000000000000;

    bitBoards[@intFromEnum(pieceBB.white)] = bitBoards[@intFromEnum(pieceBB.wPawn)] |
                                             bitBoards[@intFromEnum(pieceBB.wBishop)] |
                                             bitBoards[@intFromEnum(pieceBB.wKnight)] |
                                             bitBoards[@intFromEnum(pieceBB.wRook)] |
                                             bitBoards[@intFromEnum(pieceBB.wQueen)] |
                                             bitBoards[@intFromEnum(pieceBB.wKing)];


    bitBoards[@intFromEnum(pieceBB.black)] = bitBoards[@intFromEnum(pieceBB.bPawn)] |
                                             bitBoards[@intFromEnum(pieceBB.bBishop)] |
                                             bitBoards[@intFromEnum(pieceBB.bKnight)] |
                                             bitBoards[@intFromEnum(pieceBB.bRook)] |
                                             bitBoards[@intFromEnum(pieceBB.bQueen)] |
                                             bitBoards[@intFromEnum(pieceBB.bKing)];

    bitBoards[@intFromEnum(pieceBB.all)] =  bitBoards[@intFromEnum(pieceBB.white)] | bitBoards[@intFromEnum(pieceBB.black)];

    empty = ~bitBoards[@intFromEnum(pieceBB.all)];
}

pub fn getSquareChar(sq: u6) *const [2]u8{
    return &squaresChar[sq];
}

