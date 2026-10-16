const std = @import("std");

// funciones que simd que no encontre en zig

pub inline fn pext(src: u64, mask: u64) u64{
    const method = struct{
        extern fn @"llvm.x86.bmi.pext.64"(u64, u64) u64;
    };
    return method.@"llvm.x86.bmi.pext.64"(src, mask);
}

pub inline fn pdep(val: u64, mask: u64) u64{
    const method = struct{
        extern fn @"llvm.x86.bmi.pdep.64"(u64, u64) u64;
    }; 
    return method.@"llvm.x86.bmi.pdep.64"(val, mask);
}

