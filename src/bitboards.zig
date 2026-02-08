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

const bishopMagics : [64]u64 = undefined;
const rookMagics : [64]u64 = undefined;

pub const bishopMagicTable  : [64][512]u64 = initBishopMagicTable();
pub const rookMagicTable : [64][4096]u64 = initRookMagicTable();

pub fn random64Bit() u64{
    var prng = std.Random.DefaultPrng.init(1);
    const time : i64 = std.time.microTimestamp();
    const rd =  @mulWithOverflow(std.math.cast(u64, time).?, 0x1f2c9e);
    const res =  @mulWithOverflow(prng.random().int(u64), rd[0]) ;
    return res[0];
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
    @setEvalBranchQuota(2721440);
    comptime var res : u64 = 0;

    const rank : u3 = @intCast(square >> 3);
    const file : u3 = @intCast(square & 7);
    
    comptime var r1 = @addWithOverflow(rank, 1);
    comptime var r2 = @addWithOverflow(file, 1);
    comptime var r3 = @subWithOverflow(rank, 1);
    comptime var r4 = @subWithOverflow(file, 1);

    while(r1[0] < 8 and r1[1] != 1) {  // rank up
        if(blokers & ((@as(u64, 1) << @intCast(8 * @as(u8, r1[0]))) << file) > 0){
            res |=( (@as(u64, 1) << @intCast( 8 * @as(u8, r1[0]) )) << file ); 
            break;
        }
        
        res |=( (@as(u64, 1) << @intCast( 8 * @as(u8, r1[0]) )) << file );
        r1 = @addWithOverflow(r1[0], 1);
    }

    while(r2[0] < 8 and r2[1] != 1){  // file right
        if(blokers & (@as(u64, 1) << r2[0]) << @intCast(8 * @as(u8, rank)) > 0){
            res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
            break;
        }

        res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
        r2 = @addWithOverflow(r2[0], 1);
    }


    while(r3[0] >= 0 and r3[1] != 1){ // rank down
        if((blokers & (((@as(u64, 1)) << @intCast(8 * @as(u8, r3[0]))) << file) ) > 0){
            res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;
            break;
        }
        std.log.debug("r3 {}\n", .{r3[0]});
        res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;
        
        r3 = @subWithOverflow(r3[0], 1);
    }

    while(r4[0] >= 0 and r4[1] != 1){   // file left
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
    @setEvalBranchQuota(100000000);
    comptime var res : u64 = 0;

    const rank : u3 = @intCast(square >> 3);
    const file : u3 = @intCast(square & 7);
    
    comptime var r11 = @addWithOverflow(rank, 1); // 1 rank
    comptime var r12 = @addWithOverflow(file, 1); // 2 file

    inline while(r11[0] < 8 and r12[0] < 8 and r11[1] != 1 and r12[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r11[0])) << r12[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r11 = @addWithOverflow(r11[0], 1);
        r12 = @addWithOverflow(r12[0], 1);
    }

    comptime var r21 = @subWithOverflow(rank, 1);
    comptime var r22 = @addWithOverflow(file, 1);

    inline while(r21[0] >= 0 and r22[0] < 8 and r21[1] != 1 and r22[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r21[0])) << r22[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r21 = @subWithOverflow(r21[0], 1);
        r22 = @addWithOverflow(r22[0], 1);
    }

    comptime var r31 = @subWithOverflow(rank, 1);
    comptime var r32 = @subWithOverflow(file, 1);

    inline while(r31[0] >= 0 and r32[0] >= 0 and r31[1] != 1 and r32[1] != 1){
        const nPos = @as(u64, 1) << @intCast(8 * @as(u8, r31[0])) << r32[0];

        if(blokers & nPos > 0){
            res |= nPos;
            break;
        }

        res |= nPos;
        r31 = @subWithOverflow(r31[0], 1);
        r32 = @subWithOverflow(r32[0], 1);
    }

    comptime var r41 = @addWithOverflow(rank, 1);
    comptime var r42 = @subWithOverflow(file, 1);

    inline while(r41[0] < 8 and r42[0] >= 0 and r41[1] != 1 and r42[1] != 1){
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

fn initRookMagicTable() [64][4096]u64{
    var masks: [64][4096]u64 = undefined;
    comptime var i : u8 = 0;
    inline for(0..64) |_|{
        comptime var subset : u64 = 0;
        comptime var nsubset : u64 = 0;

        inline while(true){ // start the subset brute force of i square

            //std.log.debug("subset pos {}: 0x{X}\n", .{nsubset, subset});

            masks[i][nsubset] = comptime generateRookAttacks(i, subset);

            //std.log.debug("subset moves: 0x{X}\n", .{rookMagicTable[i][nsubset]});
            
            subset = (@subWithOverflow(subset, rookMask[i])[0]) & rookMask[i];

            nsubset += 1;
            if(nsubset >= 4096){
                break;
            }
            
        }
        i += 1;
    }
    return masks;
}

fn initBishopMagicTable() [64][512]u64{
    var masks: [64][512]u64 = undefined;
    comptime var i: u6 = 0;
    inline for(0..63) |_|{

        comptime var subset: u64 = 0;
        comptime var nsubset: u64 = 0;

        while(true){

            masks[i][nsubset] = generateBishopAttacks(i, subset);

            subset = @subWithOverflow(subset, bishopMask[i])[0] & bishopMask[i];

            nsubset += 1;
            if(nsubset >= 512){
                break;
            }
        }

        i += 1;
    }
    return masks;
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
    bb &= rookMask[sq];
    bb *= rookMagics[sq];
    bb >>= 64-12;
    return rookMagicTable[sq][bb];
}

pub fn getBishopAttacks(bb : u64, sq : u8) u64{
    bb &= bishopMask[sq];
    bb *= bishopMagics[sq];
    bb >>= 64-9;
    return bishopMagicTable[sq][bb];
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
   
}

