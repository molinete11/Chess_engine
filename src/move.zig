const std = @import("std");
const Self = @This();

const BitSetU16 = std.bit_set.IntegerBitSet(u16);

pub const Flags = enum(u4){
    quietMove = 0,
    doublePawnPush = 0b0001,
    kingSideCastle = 0b0010,
    queenSideCastle = 0b0011,
    capture = 0b0100,
    epCapture = 0b0101,
    knightPromotion = 0b1000,
    bishopPromotion = 0b1001,
    rookPromotion = 0b1010,
    queenPromotion = 0b1011,
    knightPromotionCapture = 0b1100,
    bishopPromotionCapture = 0b1101,
    rookPromotionCapture = 0b1110,
    queenPromotionCapture = 0b1111,

    pub inline fn toInt(self: @This()) u4{
        return @intFromEnum(self);
    }
};

fromToFlags: u16,

pub inline fn New(src: u6, dst: u6, f: Flags) 
            Self
{
    return .{
        .fromToFlags = src | (@as(u12, dst) << 6) | (@as(u16, @intFromEnum(f)) << 12),
    };    
}

pub inline fn from(self: Self) u6{
    return @intCast(self.fromToFlags & @as(u16, @intCast(0x3f)));
}

pub inline fn to(self: Self) u6{
    return @intCast((self.fromToFlags & @as(u16, @intCast(0xfc0))) >> 6) ;
}

pub inline fn fromTo(self: Self) u12{
    return @intCast(self.fromToFlags & @as(u16, @intCast(0xFFF)));
}

pub inline fn flag(self: Self) Flags{
    return @enumFromInt((self.fromToFlags & @as(u16, @intCast(0xF000))) >> 12 );
}

pub inline fn isQuiet(self: Self) bool{return self.flag() == .quietMove;}
pub inline fn isDoublePawnPush(self: Self) bool{return self.flag() == .doublePawnPush;}
pub inline fn isCapture(self: Self) bool{return self.flag() == .capture or @intFromEnum(self.flag()) >= 10;}

pub inline fn isKingSideCastle(self: Self) bool{return self.flag() == .kingSideCastle;}
pub inline fn isQueenSideCastle(self: Self) bool{return self.flag() == .queenSideCastle;}
pub inline fn isEnPassantCapture(self: Self) bool{return self.flag() == .epCapture;}

pub inline fn isPromotion(self: Self) bool{return @intFromEnum(self.flag()) >= 6;}

pub inline fn isBishopPromotion(self: Self) bool{return self.flag() == .bishopPromotion;}
pub inline fn isKnightPromotion(self: Self) bool{return self.flag() == .knightPromotion;}
pub inline fn isRookPromotion(self: Self) bool{return self.flag() == .rookPromotion;}
pub inline fn isQueenPromotion(self: Self) bool{return self.flag() == .queenPromotion;}

pub inline fn isBishopPromotionCapture(self: Self) bool{return self.flag() == .bishopPromotionCapture;}
pub inline fn isKnightPromotionCapture(self: Self) bool{return self.flag() == .knightPromotionCapture;}
pub inline fn isRookPromotionCapture(self: Self) bool{return self.flag() == .rookPromotionCapture;}
pub inline fn isQueenPromotionCapture(self: Self) bool{return self.flag() == .queenPromotionCapture;}

