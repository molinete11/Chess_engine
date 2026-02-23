const board = @import("bitboards.zig");
const m = @import("moves.zig");
const std = @import("std");

const defaultFen: []const u8 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

var stdoutBuffer: [1024]u8 = undefined;
var stdinBuffer: [1024]u8 = undefined;

var stdoutWriter = std.fs.File.stdout().writer(&stdoutBuffer);
const stdout = &stdoutWriter.interface;

var stdinReader = std.fs.File.stdin().reader(&stdinBuffer);
const stdin = &stdinReader.interface;

const cmpstr = std.mem.eql;

pub fn uciInit() void{
    board.initStartingPos();
}

pub fn uciLoop() !void{
    var exit: bool = false;

    var buffer: []u8 = undefined;

    while(!exit){
        buffer = try stdin.takeDelimiterInclusive('\n');
        buffer = buffer[0..buffer.len-1];
        var tokens = std.mem.splitSequence(u8, buffer, " ");
        const token: []const u8 = tokens.first();

        if(cmpstr(u8, token, "quit")){
            exit = true;

        }
        else if(cmpstr(u8, token, "uci")){
            try stdout.print("id name MoFish\n", .{});
            try stdout.print("id author Molinete\n", .{});
            try stdout.print("uciok\n", .{});
        }
        else if(cmpstr(u8, token, "position")){
            parsePosition(tokens.rest());
        }
        else if(cmpstr(u8, token, "ucinewgame")){

        }
        else if(cmpstr(u8, token, "isready")){
            try stdout.print("uciok\n", .{});
        }
        else if(cmpstr(u8, token, "go")){
            
        }
        else if(cmpstr(u8, token, "d")){
            try printBoard();
        }
        else if(cmpstr(u8, token, "playmove")){
            if(tokens.next()) |move|{
                parseMove(move);
            }
        }

        try stdout.flush();
    }
}

fn printBoard() !void{
    for(0..8) |i|{
        for(0..8)|j|{
            const piece: u64 = board.bitBoards[@intFromEnum(board.pieceBB.all)] & (@as(u64, 1) << @intCast(i * 8 + j));
            const pSymbol = getPieceSymbol(piece);
            try stdout.print("{c}", .{pSymbol});
        }
        try stdout.print("\n", .{});
    }
}

fn getPieceSymbol(piece: u64) u8{
    for(0..12)|i|{
        if(board.bitBoards[i] & piece > 0){
            switch (i) {
                @intFromEnum(board.pieceBB.wPawn) => return 'P',
                @intFromEnum(board.pieceBB.wBishop) => return 'B',
                @intFromEnum(board.pieceBB.wKnight) => return 'N',
                @intFromEnum(board.pieceBB.wRook) => return 'R',
                @intFromEnum(board.pieceBB.wQueen) => return 'Q',
                @intFromEnum(board.pieceBB.wKing) => return 'K',

                @intFromEnum(board.pieceBB.bPawn) => return 'p',
                @intFromEnum(board.pieceBB.bBishop) => return 'b',
                @intFromEnum(board.pieceBB.bKnight) => return 'n',
                @intFromEnum(board.pieceBB.bRook) => return 'r',
                @intFromEnum(board.pieceBB.bQueen) => return 'q',
                @intFromEnum(board.pieceBB.bKing) => return 'k',
                else => return 'X',
            }
        }
    }
    return 'X';
}

fn parseUciNewGame() void{

}

fn parseFen(fen: []const u8) void{
    std.debug.print("parsing fen ...\n", .{});
    std.debug.print("{s}\n", .{fen});
}
 
fn parseMove(args: []const u8) void{
    const moves = m.generateLegalMoves();
    std.debug.print("{s}\n", .{args});
    const fileFrom: u10 = args[0] - 'a';
    const rankFrom: u10 = args[1] - '1';
    const from: u10 = rankFrom * 8 + fileFrom;

    const fileTo: u10 = args[2] - 'a';
    const rankTo: u10 = args[3] - '1';
    const to: u10 = rankTo * 8 + fileTo;

    for(0..moves.count) |i|{
        std.debug.print("{any}\n", .{moves.moves[i]});
        if(from == moves.moves[i].from and to == moves.moves[i].to){
            //std.debug.print("move found!\n", .{});
            //std.debug.print("{}, {}\n", .{from, to});
            m.makeMove(moves.moves[i]);
            break;
        }
    }

    //std.debug.print("{}, {}\n", .{moves.moves[move].from, moves.moves[move].to});   
}

fn parsePosition(args: []const u8) void{

    var tokens = std.mem.splitSequence(u8, args, " ");
    var valid = false;

    const farg = tokens.first();

    if(std.mem.eql(u8, farg, "startpos")){
        board.initStartingPos();
        valid = true;
    }else if(std.mem.eql(u8, farg, "fen")){
        var fen: Loc = undefined;
        //std.debug.print("{s}\n", .{args});
        fen.start = getToken(args, 1).start;
        fen.end =  getToken(args, 6).end;

        if(fen.end <= fen.start){
            return;
        }

        parseFen(args[fen.start..fen.end]);

        for(0..6) |_|{
            _ = tokens.next().?;
        }
        valid = true;
    }

    if(tokens.next()) |movesArg|{
        std.debug.print("move: {s}\n", .{movesArg});
        if(std.mem.eql(u8, movesArg, "moves") and valid){
            while(tokens.next()) |move|{
                std.debug.print("move: {s}\n", .{move});
            }
        }
    }
}

const Loc = struct {
    start: usize,
    end: usize,
};

fn getToken(buffer: []const u8, idx: usize) Loc{

    var currentToken: usize = 0;
    var i: usize = 0;

    var loc: Loc = undefined;

    while(i < buffer.len and currentToken != idx){
        if(buffer[i] == ' '){
            currentToken += 1;
            //std.debug.print("current token: {}\n", .{currentToken});
        }
        //std.debug.print("{}\n", .{i});
        i += 1;
    }

    if(currentToken != idx){
        return Loc{
            .start = 0,
            .end = 0,
        };
    }

    //std.debug.print("{any}\n", .{i});

    loc.start = i;
    loc.end = i;

    while(loc.end < buffer.len - 1 and buffer[loc.end] != ' '){
        loc.end += 1;
    }

    return loc;
    
}
