const std = @import("std");
const uci = @import("uci.zig");
const board = @import("bitboards.zig");
const moves = @import("moves.zig");

pub fn main() !void {
    uci.uciInit();
    //try uci.uciLoop();
    //_ = moves.generateLegalMoves();
    //for(1..8) |i|{
        //var timer = try std.time.Timer.start();
        //const start = timer.read();
        //const res = moves.perft(@intCast(i));
        //std.mem.doNotOptimizeAway(res);
        //const end = timer.read();

        //std.debug.print("peft depth {}: nodes {}, time {}s\n", .{i, res, @as(f64, @floatFromInt(end - start)) / @as(f64, 1000000000)});
    //}
    //std.debug.print("{}\n", .{moves.perft(4)});
    std.debug.print("{}\n", .{moves.perftDivide(7)});
}

test "rookMagic" {
    var sq: u8 = 0;
    for(0..64) |_|{
        const n: u64 = @as(u64, 1) << @intCast(@popCount(board.rookMask[sq]));

        var j: u32 = 0;
        
        var subset: u64 = 0;

        j = 0;
        while(j < n){
            const key = (board.rookMagics[sq] *% subset) >> board.rookShifts[sq];
            const att = board.generateRookAttacks(sq, subset);

            if(board.rookMagicTable[sq][key] != att){
                std.debug.print("0x{x}\n", .{board.rookMagics[sq]});
                try std.testing.expect(board.rookMagicTable[sq][key] == att);
            }

            subset = (subset -% board.rookMask[sq]) & board.rookMask[sq];
            j += 1;
        }
        sq += 1;
    }
}

test "bishopMagic"{
    var sq: u8 = 0;
    for(0..64) |_|{
        const n: u64 = @as(u64, 1) << @intCast(@popCount(board.bishopMask[sq]));

        var j: u32 = 0;
        
        var subset: u64 = 0;

        j = 0;
        while(j < n){
            const key = (board.bishopMagics[sq] *% subset) >> board.bishopShifts[sq];
            const att = board.generateBishopAttacks(sq, subset);

            if(board.bishopMagicTable[sq][key] != att){
                std.debug.print("0x{x}\n", .{board.bishopMagics[sq]});
                break;
            }

            subset = (subset -% board.bishopMask[sq]) & board.bishopMask[sq];
            j += 1;
        }
        sq += 1;
    }
}

test "perft" {
    uci.uciInit();
    
    for(0..9) |i|{
        std.debug.print("perft {}: {}\n", .{i, moves.perft(@intCast(i))});
    }
}