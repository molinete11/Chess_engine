const std = @import("std");
const expect = std.testing.expect;

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

var bitBoards : [12]u64 = undefined;

const notAFile : u64 = 0xfefefefefefefefe;
const notHFile : u64 = 0x7f7f7f7f7f7f7f7f;
const notABFile : u64 = 0xfcfcfcfcfcfcfcfc;
const notHGFile : u64 = 0x3f3f3f3f3f3f3f3f;

const rank2 : u64 = 0x000000000000FF00;
const rank7 : u64 = 0x00FF000000000000;

var pawnLookUpTable   : [2][64]u64 = undefined;
var knightLookUpTable : [64]u64 = undefined;
var kingLookUpTable   : [64]u64 = undefined;

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

fn printBitBoard(bb : u64) void {
    for(0..64) |i|{
        const b = if (bb & (1 << i)) 1 else 0;
        std.debug.print("{}", .{b});
    }
}


pub fn initBitBoards() void {
    initPawnLookUpTable();
    initKnightLookUpTable();

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