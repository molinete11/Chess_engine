const std = @import("std");

pub const keys: [2][6][64]u64 = generatePieceKeys();

pub const side_keys: [2]u64 = generateRandoms(2);

pub const ep_file: [8]u64 = generateRandoms(8);

pub const castling_rights: [4]u64 = generateRandoms(4);

fn generatePieceKeys() [2][6][64]u64{
    @setEvalBranchQuota(20000000);

    var k: [2][6][64]u64 = undefined;

    inline for(0..2) |j|{
        inline for(0..6) |i|{
            k[j][i] = generateRandoms(64);
        }
    }


    return k;
}

fn generateRandoms(N: comptime_int) [N]u64{

    @setEvalBranchQuota(20000000);
    var isaac = std.Random.Isaac64.init(0xFF21AC00);
    const prgn = isaac.random();

    var rnd_numbers: [N]u64 = undefined;

    for(0..N)|i|{
        rnd_numbers[i] = prgn.int(u64);
    }

    return rnd_numbers;
}