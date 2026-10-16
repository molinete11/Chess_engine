const std = @import("std");
const simd = @import("simd.zig");
const c = @import("c");
const Bitboard = std.bit_set.Integer(64);

// rook size = 102400
// bishop size = 5248
// tot size = 107648

// bishop offsets sq 0 starts at 102400

pub const bishop_masks:     [64]Bitboard = initBishopMasks();
pub const rook_masks:       [64]Bitboard = initRookMasks();

pub const bishop_offsets:   [64]u32 = initBishopOffsets();
pub const rook_offsets:     [64]u32 = initRookOffsets();

pub const arr_attacks:      [107648]Bitboard = initArrAttacks(); // 841 Kb
pub const knight_move_set:  [64]Bitboard = initKnightLookUpTable();
pub const king_move_set:    [64]Bitboard = initKingMoveSets();
pub const pawn_move_set:    [2][64]Bitboard = initPawnMoveSets();
pub const pawn_att_set:     [2][64]Bitboard = initPawnAttSets();

fn SubsetIterator(set: Bitboard) type{
    const subset_count = std.math.pow(u64, 2, @popCount(set.mask));

    return struct {
        set: Bitboard = set,
        subset: Bitboard = set,
        max_subset_num: u64 = subset_count,
        current_subset_n: u64 = 0,

        const InnerSelf = @This();

        pub fn next(self: *InnerSelf) ?Bitboard{
            if(self.current_subset_n >= self.max_subset_num) return null;
            self.subset = self.set.intersectWith(.{ .mask = self.subset.mask -% self.set.mask });
            self.current_subset_n += 1;
            return self.subset;
        }
    };
}

fn initRookOffsets() [64]u32{
    const table: [64]u32 = .{
        0, 4096, 2048, 2048, 2048, 2048, 2048, 2048, 4096,
        2048, 1024, 1024, 1024, 1024, 1024, 1024, 2048,
        2048, 1024, 1024, 1024, 1024, 1024, 1024, 2048,
        2048, 1024, 1024, 1024, 1024, 1024, 1024, 2048,
        2048, 1024, 1024, 1024, 1024, 1024, 1024, 2048,
        2048, 1024, 1024, 1024, 1024, 1024, 1024, 2048,
        2048, 1024, 1024, 1024, 1024, 1024, 1024, 2048,
        4096, 2048, 2048, 2048, 2048, 2048, 2048,
    };

    var offsets: [64]u32 = @splat(0);

    var offset: u32 = 0;

    inline for(0..64) |i|{
        offset += table[i];
        offsets[i] = offset;
    }

    return offsets;
}

fn initBishopOffsets() [64]u32{
    const table: [64]u32 = .{
        0, 64, 32, 32, 32, 32, 32, 32, 64,
        32, 32, 32, 32, 32, 32, 32, 32,
        32, 32, 128, 128, 128, 128, 32, 32,
        32, 32, 128, 512, 512, 128, 32, 32,
        32, 32, 128, 512, 512, 128, 32, 32,
        32, 32, 128, 128, 128, 128, 32, 32,
        32, 32, 32, 32, 32, 32, 32, 32,
        64, 32, 32, 32, 32, 32, 32
    };

    const start_offset = 102400;

    var offsets: [64]u32 = @splat(0);
    var offset: u32 = start_offset;

    inline for(0..64) |i|{
        offset += table[i];
        offsets[i] = offset;
    }

    return offsets;
}

fn initBishopMasks() [64]Bitboard{

    const m_diag: u64 = 0x8040201008040201;
    const a_diag: u64 = 0x102040810204080;

    var masks: [64]Bitboard = undefined;

    const borders: u64 = 0xff00000000000000 | 0x8080808080808080 | 0xff | 0x101010101010101;

    for(0..64) |i|{
        masks[i] = .empty;
        const rank: i6 = @bitCast(@as(u6, @intCast(i >> 3)));
        const file: i6 = @bitCast(@as(u6, @intCast(i & 7)));

        const m_shift: i6 = file - rank;
        const a_shift: i6 = 7 - file - rank;

        masks[i].mask |= if(m_shift >= 0) m_diag >> @as(u6, @bitCast(m_shift)) * 8 else @shlWithOverflow(m_diag, @abs(m_shift) * 8)[0];
        masks[i].mask |= if(a_shift >= 0) a_diag >> @as(u6, @bitCast(a_shift)) * 8 else @shlWithOverflow(a_diag, @abs(a_shift) * 8)[0];
        masks[i].mask ^= @as(u64, 1) << @intCast(i);
        masks[i].mask &= ~borders;
    }

    return masks;
}

fn initRookMasks() [64]Bitboard{
    const rank1: u64 = 0xff;
    const afile: u64 = 0x101010101010101;

    var masks: [64]Bitboard = undefined;

    for(0..64) |i|{
        masks[i] = .empty;
        const rank = i >> 3;
        const file = i & 7;

        masks[i].mask |= (rank1 << (8 * rank)) & ~(@as(u64, 0x8080808080808080 | 0x101010101010101));
        masks[i].mask |= (afile << file) & ~(@as(u64, 0xff000000000000ff));
        masks[i].mask =  masks[i].mask & (masks[i].mask ^ (@as(u64, 1) << @intCast(i)));
    }

    return masks;
}

fn pext(src: u64, mask: u64) u64{ 
    @setRuntimeSafety(false);
    var res: u64 = 0;
    var bb: u64 = 1;
    var mask_c: u64 = mask;
    while(mask_c > 0): (bb += bb){
        if((src & mask_c & (~mask_c + 1)) > 0) res |= bb;
        mask_c &= mask_c - 1;
    }
    return res;
}

fn initArrAttacks() [107648]Bitboard{
    @setEvalBranchQuota(10000000);
    var att: [107648]Bitboard = undefined;

    inline for(0..att.len) |i|{
        att[i] = .empty;
    }
    
    for(0..64) |i|{
        const set = rook_masks[i];
        var subset_iter: SubsetIterator(.{.mask = set.mask}) = .{};
        while(subset_iter.next()) |subset|{
            att[rook_offsets[i] + pext(subset.mask, set.mask)].mask = genRookMoves(@intCast(i), subset.mask) ^ @as(u64, 1) << @intCast(i);
        }
    }

    for(0..64) |i|{
        const set = bishop_masks[i];
        var subset_iter: SubsetIterator(.{.mask = set.mask}) = .{};

        while(subset_iter.next()) |subset|{   
            att[bishop_offsets[i] + pext(subset.mask, set.mask)].mask = genBishopMoves(@intCast(i), subset.mask) ^ @as(u64, 1) << @intCast(i);
        }
    }
    return att;
}

fn ray(sq: u6, occ: u64, dir: i6, limit: u64) u64{
    var mask: u64 = 0;
    var i: usize = 0;

    var next_sq: u64 = 0;

    var sq_bitboard: Bitboard = .empty;
    sq_bitboard.set(sq);

    if(dir >= 0){
        next_sq = sq_bitboard.mask << @abs(dir) * i;
    }else{
        next_sq = sq_bitboard.mask >> @abs(dir) * i;
    }

    while(true){
        if(((next_sq & occ) > 0) or ((next_sq & limit) > 0)){
            mask |= next_sq;
            return mask;
        }

        mask |= next_sq;
        i += 1;

        if(i >= 8) return mask;
        if(dir >= 0){
            next_sq <<= @abs(dir);
        }else{
            next_sq >>= @abs(dir);
        }  
    }   
}

fn genRookMoves(sq: u6, occ: u64) u64{
    return ray(sq, occ,  8, 0xff00000000000000)  | 
           ray(sq, occ,  1, 0x8080808080808080)  | 
           ray(sq, occ, -8, 0xff) | 
           ray(sq, occ, -1, 0x101010101010101); 
}

fn genBishopMoves(sq: u6, occ: u64) u64{
    return ray(sq, occ,  9, 0xff00000000000000 | 0x8080808080808080) | 
           ray(sq, occ, -7, 0xff | 0x8080808080808080)  | 
           ray(sq, occ, -9, 0xff | 0x101010101010101)  | 
           ray(sq, occ,  7, 0xff00000000000000 | 0x101010101010101); 
}

fn initKingMoveSets() [64]Bitboard {
    var masks: [64]Bitboard = undefined;
    const notAFile: u64 = 0xfefefefefefefefe;
    const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
    for (0..64) |i| {
        masks[i] = .empty;
        const pos: u64 = @as(u64, 1) << @intCast(i);
        const sides: u64 = ((pos << 1) & notAFile) | ((pos >> 1) & notHFile);
        masks[i].mask = ((sides | pos) << 8) | ((sides | pos) >> 8) | sides;
    }
    return masks;
}

fn initPawnAttSets() [2][64]Bitboard {
    var att: [2][64]Bitboard = undefined;
    const notAFile: u64 = 0xfefefefefefefefe;
    const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
    for (0..64) |i| {
        att[0][i] = .empty;
        att[1][i] = .empty;
        const pos: u64 = @as(u64, 1) << @intCast(i);
        att[0][i].mask = (pos << 9 & notAFile) | (pos << 7 & notHFile); // WHITE
        att[1][i].mask = (pos >> 7 & notAFile) | (pos >> 9 & notHFile); // BLACK
    }
    return att;
}

fn initPawnMoveSets() [2][64]Bitboard {
    var moves: [2][64]Bitboard = undefined;
    const rank2: u64 = 0xff00;
    const rank7: u64 = 0xff000000000000;
    for (0..64) |i| {
        moves[0][i] = .empty;
        moves[1][i] = .empty;
        const pos: u64 = @as(u64, 1) << @intCast(i);
        moves[0][i].mask = (pos << 8) | ((pos & rank2) << 16); // WHITE
        moves[1][i].mask = (pos >> 8) | ((pos & rank7) >> 16); // BLACK
    }
    return moves;
}

fn initKnightLookUpTable() [64]Bitboard {
    var masks: [64]Bitboard = undefined;
    const notAFile: u64 = 0xfefefefefefefefe;
    const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
    const notABFile: u64 = 0xfcfcfcfcfcfcfcfc;
    const notHGFile: u64 = 0x3f3f3f3f3f3f3f3f;
    for (0..64) |i| {
        masks[i] = .empty;
        const pos: u64 = @as(u64, 1) << @intCast(i);
        masks[i].mask = ((pos << 17) & notAFile) |
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

pub inline fn getBishopMask(sq: usize) Bitboard{
    const m_diag: u64 = 0x8040201008040201;
    const a_diag: u64 = 0x102040810204080;

    var set: Bitboard = .empty;
    const rank: i6 = @bitCast(@as(u6, @intCast(sq >> 3)));
    const file: i6 = @bitCast(@as(u6, @intCast(sq & 7)));

    const m_shift: i6 = file - rank;
    const a_shift: i6 = 7 - file - rank;

    set.mask |= if(m_shift >= 0) m_diag >> @as(u6, @bitCast(m_shift)) * 8 else @shlWithOverflow(m_diag, @abs(m_shift) * 8)[0];
    set.mask |= if(a_shift >= 0) a_diag >> @as(u6, @bitCast(a_shift)) * 8 else @shlWithOverflow(a_diag, @abs(a_shift) * 8)[0];
    set.mask ^= @as(u64, 1) << @intCast(sq);

    return set;
}

pub inline fn getRookMask(sq: usize) Bitboard{
    const rank1: u64 = 0xff;
    const afile: u64 = 0x101010101010101;
    
    var set: Bitboard = .empty;

    const rank: u6 = @as(u6, @intCast(sq)) >> 3;
    const file: u6 = @as(u6, @intCast(sq)) & 7;

    set.mask |= (rank1 << (8 * rank));
    set.mask |= (afile << file);

    return set;
}

pub inline fn getBishopMoveSet(sq: usize, occ: u64) Bitboard{
    return arr_attacks[bishop_offsets[sq] + simd.pext(occ, bishop_masks[sq].mask)];
}

pub inline fn getRookMoveSet(sq: usize, occ: u64) Bitboard{
    return arr_attacks[rook_offsets[sq] + simd.pext(occ, rook_masks[sq].mask)];
}

pub inline fn getQueenMoveSet(sq: usize, occ: u64) Bitboard{
    return getBishopMoveSet(sq, occ).unionWith(getRookMoveSet(sq, occ));
}

pub inline fn getKnightMoveSet(sq: usize) Bitboard{
    return knight_move_set[sq];
}

pub inline fn getKingMoveSet(sq: usize) Bitboard{
    return king_move_set[sq];
}

pub inline fn getPawnMoveSet(sq: usize, side: u1) Bitboard{
    return pawn_move_set[side][sq];
}

pub inline fn getPawnAttackSet(sq: usize, side: u1) Bitboard{
    return pawn_att_set[side][sq];
}