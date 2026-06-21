const std = @import("std");


pub fn popLstb(n: u64) u64{
    return n & (n - 1);
}

pub fn getlastBitIdx(n: u64) u6{
    return @ctz(n);
}


pub inline fn setBit(bb: u64, square: u8) u64 {
    return bb | (@as(u64, 1) << square);
}

pub inline fn popBit(bb: u64, square: u8) u64 {
    return bb & (bb ^ (@as(u64, 1) << square));
}
