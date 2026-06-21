const std = @import("std");


pub fn popLstb(n: u64) u64{
    return n & (n - 1);
}

pub fn getlastBitIdx(n: u64) u6{
    return @ctz(n);
}