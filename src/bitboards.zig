const std = @import("std");
const expect = std.testing.expect;

const side = enum(u2){
    white,
    black,
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

var bitBoards : [12]u64 = [_]u64{
    0x000000000000FF00,
    0x0000000000000024,
    0x0000000000000042,
    0x0000000000000081,
    0x0000000000000008,
    0x0000000000000010,

    0x00FF000000000000,
    0x2400000000000000,
    0x4200000000000000,
    0x8100000000000000,
    0x0800000000000000,
    0x1000000000000000,
};

const notAFile : u64 = 0xfefefefefefefefe;
const notHFile : u64 = 0x7f7f7f7f7f7f7f7f;
const notABFile : u64 = 0xfcfcfcfcfcfcfcfc;
const notHGFile : u64 = 0x3f3f3f3f3f3f3f3f;
const aFile : u64 = 0x0101010101010101;
const rank1 : u64 = 0x00000000000000FF;
const rank2 : u64 = 0x000000000000FF00;
const rank7 : u64 = 0x00FF000000000000;
const rank8 : u64 = 0xFF00000000000000;


pub const mDiagonal: u64 = 0x8040201008040201;
pub const aDiagonal: u64 = 0x102040810204080;

const pawnLookUpTable  : [2][64]u64 = initPawnLookUpTable();
const knightLookUpTable : [64]u64 = initKnightLookUpTable();
const kingLookUpTable : [64]u64 = initKingLookUpTable();

pub const bishopMask : [64]u64 = createBishopMask();
const rookMask : [64]u64 = createRookMask();


pub var bishopMagicTable  : [64][512]u64 = undefined;
pub var rookMagicTable : [64][4096]u64 = undefined;

const bishopMagics: [64]u64 = [_]u64{
    0x10440100420200,
    0x290018200860000,
    0x808018302100200,
    0x42400912C0000,
    0x1104001730000,
    0x821040500000,
    0x400480804920200,
    0x2028208008A0800,
    0x500400409020200,
    0x4000041104330200,
    0x4000040430A20100,
    0x4040400800000,
    0x40420450000,
    0xC808A0802E80400,
    0xA804126000,
    0x4010288044200,
    0x8002002D00200,
    0x442100902040400,
    0x800C100490200,
    0x80D000804910000,
    0x1000890401000,
    0x1010200D10400,
    0x804068081800,
    0x801908E11000,
    0x8200040340100,
    0x10900004770200,
    0x22020001080200,
    0xC04004010200,
    0x200840000802000,
    0x8020000C04200,
    0x2220800411000,
    0x2002018000404800,
    0x6002904000D00200,
    0x4300404480100,
    0x884220810290800,
    0x42008040100,
    0x2800440400584100,
    0x10040020C91000,
    0x8080080821B0800,
    0x18100400E0200,
    0x4022004121000,
    0x8004044228000200,
    0x101008040600C00,
    0x3000004201900800,
    0x10088101C20C00,
    0x1101100450200,
    0x2024100201442200,
    0x1020400480900,
    0x80882402E00000,
    0x6028404028A0800,
    0x104012C4000,
    0x80304880000,
    0x40004005070000,
    0x410024A0000,
    0x8083004C60000,
    0x2C040422620000,
    0x1010220210130800,
    0x808201352000,
    0x8000000100A80400,
    0x8018000840400,
    0x2000000010120200,
    0x2120800410463200,
    0x1000440802840C00,
    0x10040C1000D70100,
};
var rookMagics: [64]u64 = [_]u64{  
    0x280008010604000,
    0x8080008410644000,
    0x80001024824000,
    0x180008010624000,
    0x80002180314000,
    0x800022108A4000,
    0x50800080A0904000,
    0xA80003080604000,
    0xC080104000218000,
    0x480104000608000,
    0x80025080204000,
    0x4100108000204100,
    0x80104000218000,
    0x1080001029824000,
    0x480009220804000,
    0x80008020144000,
    0x80002010814000,
    0x280002080B54000,
    0x1480002030824000,
    0x4280104000A08000,
    0x80002010854000,
    0x800080601A4000,
    0x2800020108A4000,
    0x8000102080C000,
    0x80001020804000,
    0x4080002080F64000,
    0x880009080A04000,
    0x180028420904000,
    0x8080008010614000,
    0x880104000268000,
    0x80001080224000,
    0x80006080384000,
    0x800080A0984000,
    0x8000802871C000,
    0x80002080304000,
    0x80108000664000,
    0x6080002010854000,
    0x80008024154000,
    0x80001280E64000,
    0x80002080944000,
    0x80800010822C4000,
    0x800080302A4000,
    0x8080008020784000,
    0x20800080A0914000,
    0x80002088104000,
    0x80001080E24000,
    0x180001480214000,
    0x8080002088104000,
    0x1280008022F04000,
    0x80008020194000,
    0x80091080604000,
    0x80002081514000,
    0x80001080A04000,
    0x1800080213CC000,
    0x8000A010894000,
    0x1080002080B34000,
    0x480002080904000,
    0x8480002481534000,
    0x80008014294000,
    0x80002080504000,
    0x80008820344000,
    0x80008090244000,
    0x80048224104000,
    0x500130020C28000,
};

const bishopShifts: [64]u6 = [_]u6{
    58, 59, 59, 59, 59, 59, 59, 58,
    59, 59, 59, 59, 59, 59, 59, 59,
    59, 59, 57, 57, 57, 57, 59, 59,
    59, 59, 57, 55, 55, 57, 59, 59,
    59, 59, 57, 55, 55, 57, 59, 59,
    59, 59, 57, 57, 57, 57, 59, 59,
    59, 59, 59, 59, 59, 59, 59, 59,
    58, 59, 59, 59, 59, 59, 59, 58,
};

const rookShifts: [64]u6 = [_]u6{
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

fn generateRookAttacks(square : u8, blokers : u64) u64{
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
        std.log.debug("r3 {}\n", .{r3[0]});
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


fn findBishopMagic(sq: u8) u64{
    var magic: u64 = randomWithFewerBytes();
    var subset: u64 = 0;

    const n: u64 = @as(u64, 1) << @intCast(@popCount(bishopMask[sq]));

    var j: u32 = 0;

    var used: [512]u64 = undefined;

    for(0..n) |k|{
        used[k] = 0;
    }

    while(j < n){
        const key = @mulWithOverflow(magic, subset)[0] >> bishopShifts[sq];
        const att = generateBishopAttacks(sq, subset);

        if(used[key] == 0){

            used[key] = att;

        }else if(used[key] != att){
            j = 0;
            subset = 0;
            magic = randomWithFewerBytes();
            for(0..n) |k|{
                used[k] = 0;
            }
            continue;
        }

        subset = @subWithOverflow(subset, bishopMask[sq])[0] & bishopMask[sq];
        j += 1;
    }

    return magic;
}

fn findRookMagic(sq: u8) u64{
    var magic: u64 = randomWithFewerBytes();
    var subset: u64 = 0;

    const n: u64 = @as(u64, 1) << @intCast(@popCount(rookMask[sq]));

    var j: u32 = 0;

    var used: [4096]u64 = undefined;

    for(0..n) |k|{
        used[k] = 0;
    }

    while(j < n){
        const key = @mulWithOverflow(magic, subset)[0] >> rookShifts[sq];
        const att = generateRookAttacks(sq, subset);

        if(used[key] == 0){

            used[key] = att;

        }else if(used[key] != att){
            j = 0;
            subset = 0;
            magic = randomWithFewerBytes();
            for(0..n) |k|{
                used[k] = 0;
            }
            continue;
        }

        subset = @subWithOverflow(subset, rookMask[sq])[0] & rookMask[sq];
        j += 1;
    }

    return magic;
}

pub fn createBishopMask() [64]u64{
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
        const mask : u64 = (((rank1 << (@as(u6, rank) * 8)) & (notAFile & notHFile)) | ((aFile << file) & ~(rank1 | rank8)));
        //std.debug.print("0x{X}\n", .{mask});
        masks[i] = mask & (mask ^ (@as(u64, 1) << @intCast(i)));
        //std.debug.print("{}: 0x{X}\n", .{i,rookMask[i]});
    }
    return masks;
}

fn initPawnLookUpTable() [2][64]u64{
    var moves: [2][64]u64 = undefined;
    for(0..64) |i | {
        const pos : u64 = @as(u64, 1) << @intCast(i);
        moves[0][i] = (pos << 8) | ((pos & rank2) << 16);
        moves[1][i] = (pos >> 8) | ((pos & rank7) >> 16);
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

fn initKingLookUpTable() [64]u64{
    var masks: [64]u64 = undefined;
    for(0..64) |i|{
        const pos : u64 = @as(u64, 1) << @intCast(i);
        const sides : u64 = ((pos << 1) & notAFile) | ((pos >> 1) & notHFile);
        masks[i] = ((sides | pos) << 8) | ((sides | pos) >> 8) | sides;
    }
    return masks;
}

pub fn getRookAttacks(bb : u64, sq : u8) u64{
    var occ: u64 = bb & rookMask[sq];
    occ = @mulWithOverflow(occ, rookMagics[sq])[0];
    occ >>= rookShifts[sq];
    return rookMagicTable[sq][occ];
}

pub fn getBishopAttacks(bb: u64, sq: u8) u64{
    var occ: u64 = bb & bishopMask[sq];
    occ = @mulWithOverflow(occ, bishopMagics[sq])[0];
    occ >>= bishopShifts[sq];
    return bishopMagicTable[sq][occ];
}

pub fn printBitBoard(bb : u64) void {
    var i : u6 = 63;
    while(i > 0){
        const pos = @as(u64, 1) << @intCast(i);
        const b : u8 = if ((bb & pos) > 0) 1 else 0;
        std.debug.print("{}", .{b});
        i -= 1;
    }

    const pos = @as(u64, 1) << @intCast(i);
    const b : u8 = if ((bb & pos) > 0) 1 else 0;
    std.debug.print("{}", .{b});

    std.debug.print("\n", .{});
}

pub fn initBitBoards() void {
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
            const key = @mulWithOverflow(bishopMagics[i], subset)[0] >> bishopShifts[i];

            bishopMagicTable[i][key] = generateBishopAttacks(i, subset);

            subset = @subWithOverflow(subset, bishopMask[i])[0] & bishopMask[i];
            j += 1;
        }

        i += 1; 
    }

    i = 0;

    for(0..64) |_|{
        //const magic = findRookMagic(i);
        //std.debug.print("0x{X}\n", .{magic});
        const bits: u7 = @popCount(rookMask[i]);
        const n = @as(u64, 1) << @intCast(bits);
        //rookMagics[i] = magic;
        var subset: u64 = 0;
        var j: u16 = 0;

        while(j < n){
            const key = @mulWithOverflow(rookMagics[i], subset)[0] >> rookShifts[i];

            rookMagicTable[i][key] = generateRookAttacks(i, subset);

            subset = @subWithOverflow(subset, rookMask[i])[0] & rookMask[i];
            j += 1;
        }

        i += 1;
    }
}

