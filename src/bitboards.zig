const std = @import("std");
const expect = std.testing.expect;

const side = enum(u2){
    white,
    black,
};

const squares = enum(u8){
    a1, b1, c1, d1, e1, f1, g1, h1, 
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8,
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

var pawnLookUpTable   : [2][64]u64 = undefined;
var knightLookUpTable : [64]u64 = undefined;
var kingLookUpTable   : [64]u64 = undefined;

var bishopMask : [64]u64 = undefined;
var rookMask : [64]u64 = undefined;

var bishopMagics : [64]u64 = undefined;
var rookMagics : [64]u64 = undefined;

var bishopMagicTable  : [64][512]u64 = undefined;
var rookMagicTable : [64][4096]u64 = undefined;

pub fn random64Bit() u64{
    var prng = std.Random.DefaultPrng.init(1);
    const time : i64 = std.time.microTimestamp();
    const rd =  @mulWithOverflow(std.math.cast(u64, time).?, 0x1f2c9e);
    const res =  @mulWithOverflow(prng.random().int(u64), rd[0]) ;
    return res[0];
}


inline fn popLstb(bb : u64) u64{
    return bb & (bb - 1);
}

inline fn setBit(bb : u64, square : u8) u64{
    return bb | (@as(u64, 1) << square);
}

inline fn popBit(bb : u64, square : u8) u64{
    return bb & (bb ^ (@as(u64, 1) << square));
}

fn generateRookAttacks(square : u8, blokers : u64) u64{
    var res : u64 = 0;

    const rank : u3 = @intCast(square >> 3);
    const file : u3 = @intCast(square & 7);

    
    var r1 = @addWithOverflow(rank, 1) ;
    var r2 = @addWithOverflow(file, 1);
    var r3 = @subWithOverflow(rank, 1);
    var r4 = @subWithOverflow(file, 1);

    while(r1[0] < 8 and r1[1] != 1) {  // rank up
        if(blokers & ((@as(u64, 1) << @intCast(8 * @as(u8, r1[0]))) << file) > 0){ 
            break;
        }
        
        res |=( (@as(u64, 1) << @intCast( 8 * @as(u8, r1[0]) )) << file );
        r1 = @addWithOverflow(r1[0], 1);
    }

    while(r2[0] < 8 and r2[1] != 1){  // file right
        if(blokers & (@as(u64, 1) << r2[0]) << @intCast(8 * @as(u8, rank)) > 0){
            break;
        }

        res |= (@as(u64, 1) << @intCast(r2[0]) << @intCast(8 * @as(u8, rank)));
        r2 = @addWithOverflow(r2[0], 1);
    }


    while(r3[0] >= 0 and r3[1] != 1){ // rank down

        if((blokers & (((@as(u64, 1)) << @intCast(8 * @as(u8, r3[0]))) << file) ) > 0){
            break;
        }
        std.log.info("r3 {}\n", .{r3[0]});
        res |= (@as(u64, 1) << @intCast(8 * @as(u8, r3[0]))) << file;
        
        r3 = @subWithOverflow(r3[0], 1);
    }

    while(r4[0] >= 0 and r4[1] != 1){   // file left
        const cPos : u64 = (@as(u64, 1) << r4[0]) << @intCast(8 * @as(u64, rank));

        if((blokers & cPos) > 0){
            break;
        }

        res |= cPos;
        r4 = @subWithOverflow(r4[0], 1);
    }

    return res;
}

fn initRookMagicTable() void{
    for(0..64) |i|{

        std.log.debug("square {}\n", .{i});

        var subset : u64 = 0;
        var nsubset : u64 = 0;

        //const rank : u3 = @intCast(i >> 3);
        const file : u3 = @intCast(i & 7);
        _ = file;
        //const pos : u64 = @as(u64, 1) << @intCast(i);

        while(true){ // start the subset brute force of i square

            std.log.debug("subset pos {}: 0x{X}\n", .{nsubset, subset});

            rookMagicTable[i][nsubset] = generateRookAttacks(@intCast(i), subset);

            std.log.debug("subset moves: 0x{X}\n", .{rookMagicTable[i][nsubset]});
            
            subset = (@subWithOverflow(subset, rookMask[i])[0]) & rookMask[i];

            nsubset += 1;
            if(nsubset >= 4096){
                break;
            }
            
        }
    }
}


fn createBishopMask() void{

}

fn createRookMask() void{
    for(0..64) |i|{
        const rank: u3 = @intCast(i >> 3);
        const file: u3 = @intCast(i & 7);
        const mask : u64 = (((rank1 << (@as(u6, rank) * 8)) & (notAFile & notHFile)) | ((aFile << file) & ~(rank1 | rank8)));
        //std.debug.print("0x{X}\n", .{mask});
        rookMask[i] = mask & (mask ^ (@as(u64, 1) << @intCast(i)));
        //std.debug.print("{}: 0x{X}\n", .{i,rookMask[i]});
    }
}

fn initPawnLookUpTable() void{
    for(0..64) |i | {
        const pos : u64 = @as(u64, 1) << @intCast(i);
        pawnLookUpTable[0][i] = (pos << 8) | ((pos & rank2) << 16);
        pawnLookUpTable[1][i] = (pos >> 8) | ((pos & rank7) >> 16);
    }
}

fn initKnightLookUpTable() void{
    for(0..64) |i|{
        const pos : u64 =  @as(u64, 1) << @intCast(i);
        knightLookUpTable[i] = ((pos << 17) & notAFile) | 
                             ((pos << 15) & notHFile) | 
                             ((pos << 10) & notABFile) | 
                             ((pos << 6) & notHGFile) | 
                             ((pos >> 10) & notHGFile) | 
                             ((pos >> 17) & notHFile) | 
                             ((pos >> 15) & notAFile) | 
                             ((pos >> 6) & notABFile);
    }
}

fn initKingLookUpTable() void{
    for(0..64) |i|{
        const pos : u64 = @as(u64, 1) << @intCast(i);

        const sides : u64 = ((pos << 1) & notAFile) | ((pos >> 1) & notHFile);

        kingLookUpTable[i] = ((sides | pos) << 8) | ((sides | pos) >> 8) | sides;
    }
}

fn getRookAttacks(bb : u64, sq : u8) u64{
    bb &= rookMask[sq];
    bb *= rookMagics[sq];
    bb >>= 64-12;
    return rookMagicTable[sq][bb];
}

fn getBishopAttacks(bb : u64, sq : u8) u64{
    bb &= bishopMask[sq];
    bb *= bishopMagics[sq];
    bb >>= 64-9;
    return bishopMagicTable[sq][bb];
}


fn printBitBoard(bb : u64) void {
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
    initPawnLookUpTable();
    initKnightLookUpTable();
    initKingLookUpTable();
    createRookMask();

    initRookMagicTable();
}

test "LookUpTable Pawn" {
    initPawnLookUpTable();

    try expect(pawnLookUpTable[0][@intFromEnum(squares.b2)] == @as(u64, 0x2020000));
    try expect(pawnLookUpTable[0][@intFromEnum(squares.a2)] == @as(u64, 0x1010000));
    try expect(pawnLookUpTable[1][@intFromEnum(squares.b7)] == @as(u64, 0x20200000000));
}

test "LookUpTable Knight" {
    initKnightLookUpTable();

    try expect(knightLookUpTable[@intFromEnum(squares.a1)] == @as(u64, 0x20400));
    try expect(knightLookUpTable[@intFromEnum(squares.d4)] == @as(u64, 0x142200221400));
    try expect(knightLookUpTable[@intFromEnum(squares.h2)] == @as(u64, 0x40200020));
    try expect(knightLookUpTable[@intFromEnum(squares.h7)] == @as(u64, 0x2000204000000000));
}

test "LookUpTable King" {
    initKingLookUpTable();

    try expect(kingLookUpTable[@intFromEnum(squares.a1)] == @as(u64, 0x302));
    try expect(kingLookUpTable[@intFromEnum(squares.d4)] == @as(u64, 0x1c141c0000));
    try expect(kingLookUpTable[@intFromEnum(squares.h2)] == @as(u64, 0xc040c0));
    try expect(kingLookUpTable[@intFromEnum(squares.h7)] == @as(u64, 0xc040c00000000000));
}

test "rook mask"{
    createRookMask();

    try expect(rookMask[@intFromEnum(squares.a1)] == 0x01010101010101FE);
    try expect(rookMask[@intFromEnum(squares.b1)] == 0x02020202020202FD);
}