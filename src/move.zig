const BoardFlags = @import("board.zig").BoardFlags;

const Self = @This();

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

pieceBB: u4,
colorBB: u4,
captureBB: u4,
colorCaptureBB: u4,
from: u6,
to: u6,
pState: PreviousState,
flags: Flags,


pub inline fn New( from: u6, 
            to: u6, 
            flags: Flags, 
            colorBB: u4, 
            pieceBB: u4, 
            colorCaptureBB: u4,
            capturePieceBB: u4
            ) 
            Self
{
    return .{
        .from = from,
        .to = to,
        .flags = flags,
        .colorBB = colorBB,
        .pieceBB = pieceBB,
        .colorCaptureBB = colorCaptureBB,
        .captureBB = capturePieceBB,
        .pState = .{
            .board_flags = undefined, 
            .castleRights = undefined, 
            .epSquare = undefined}
    };
}

pub inline fn isQuiet(self: Self) bool{return self.flags == .quietMove;}
pub inline fn isDoublePawnPush(self: Self) bool{return self.flags == .doublePawnPush;}
pub inline fn isCapture(self: Self) bool{return self.flags == .capture or @intFromEnum(self.flags) >= 10;}

pub inline fn isKingSideCastle(self: Self) bool{return self.flags == .kingSideCastle;}
pub inline fn isQueenSideCastle(self: Self) bool{return self.flags == .queenSideCastle;}
pub inline fn isEnPassantCapture(self: Self) bool{return self.flags == .epCapture;}

pub inline fn isPromotion(self: Self) bool{return @intFromEnum(self.flags) >= 6;}

pub inline fn isBishopPromotion(self: Self) bool{return self.flags == .bishopPromotion;}
pub inline fn isKnightPromotion(self: Self) bool{return self.flags == .knightPromotion;}
pub inline fn isRookPromotion(self: Self) bool{return self.flags == .rookPromotion;}
pub inline fn isQueenPromotion(self: Self) bool{return self.flags == .queenPromotion;}

pub inline fn isBishopPromotionCapture(self: Self) bool{return self.flags == .bishopPromotionCapture;}
pub inline fn isKnightPromotionCapture(self: Self) bool{return self.flags == .knightPromotionCapture;}
pub inline fn isRookPromotionCapture(self: Self) bool{return self.flags == .rookPromotionCapture;}
pub inline fn isQueenPromotionCapture(self: Self) bool{return self.flags == .queenPromotionCapture;}

