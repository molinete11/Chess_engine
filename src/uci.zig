const search = @import("search.zig");
const std = @import("std");
const benchmark = @import("benchmark.zig");
const Board = @import("board.zig");
const Move = @import("move.zig");
const perft = @import("perft.zig");
const mem = std.mem;
const BitboardIdx = Board.PieceBitboardIdx;

const Io = std.Io;

const Self = @This();

const default_search_depth: u32 = 6;

const squares = [_][]const u8{
                "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
                "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
                "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
                "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
                "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
                "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
                "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
                "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
                };

board: Board,
writer: *Io.Writer,
reader: *Io.Reader,
io: Io,

pub fn Init(writer: *Io.Writer, reader: *Io.Reader, io: Io) Self{
    return .{
        .board = Board.init(),
        .writer = writer,
        .reader = reader,
        .io = io,
    };
}

pub fn run(self: *Self) !void{

    var exit: bool = false;

    var buffer: []u8 = undefined;

    while(!exit){
        buffer = try self.reader.takeDelimiterInclusive('\n');
        buffer = buffer[0..buffer.len-1];
        var tokens = std.mem.splitSequence(u8, buffer, " ");
        const token: []const u8 = tokens.first();

        if(mem.eql(u8, token, "quit")){
            exit = true;
        }
        else if(mem.eql(u8, token, "uci")){
            try self.writer.print("id name Muu\n", .{});
            try self.writer.print("id author Molinete11\n", .{});
            try self.writer.print("uciok\n", .{});
        }
        else if(mem.eql(u8, token, "position")){
            self.parsePosition(tokens.rest());
        }
        else if(mem.eql(u8, token, "ucinewgame")){
            self.board.restartPos();
        }
        else if(mem.eql(u8, token, "isready")){
            try self.writer.print("readyok\n", .{});
        }
        else if(mem.eql(u8, token, "go")){
            try self.parseGo(tokens.rest());
        }
        else if(mem.eql(u8, token, "d")){
            try self.printBoard();
        }else if(mem.eql(u8, token, "bench")){
            try benchmark.runBench(self.io);
        }
        else if(mem.eql(u8, token, "playmove")){
            if(tokens.next()) |move|{
                self.parseMove(move);
            }
        }else{
            try self.writer.print("unrecognized command {s}\n", .{token});
        }

        try self.writer.flush();
    }
}

fn printBoard(self: *Self) !void{
    var rank: u8 = 7;
    try self.writer.print("  ----------------------------------------------\n", .{});
    for(0..8) |_|{
        var file: u8 = 0;
        
        try self.writer.print("|", .{});
        for(0..8)|_|{
            const piece: u64 = self.board.bitboards[@intFromEnum(BitboardIdx.all)] & (@as(u64, 1) << @intCast(rank * 8 + file));
            const pSymbol = self.getPieceSymbol(piece);

            try self.writer.print("  {c}  |", .{pSymbol});
            file += 1;
        }
        try self.writer.print("\n", .{});
        try self.writer.print("  ----------------------------------------------\n", .{});
        rank -%= 1;
    }
}

fn getPieceSymbol(self: *Self, piece: u64) u8{
    for(0..12)|i|{
        if(self.board.bitboards[i] & piece > 0){
            switch (i) {
                @intFromEnum(BitboardIdx.wPawn) => return 'P',
                @intFromEnum(BitboardIdx.wBishop) => return 'B',
                @intFromEnum(BitboardIdx.wKnight) => return 'N',
                @intFromEnum(BitboardIdx.wRook) => return 'R',
                @intFromEnum(BitboardIdx.wQueen) => return 'Q',
                @intFromEnum(BitboardIdx.wKing) => return 'K',

                @intFromEnum(BitboardIdx.bPawn) => return 'p',
                @intFromEnum(BitboardIdx.bBishop) => return 'b',
                @intFromEnum(BitboardIdx.bKnight) => return 'n',
                @intFromEnum(BitboardIdx.bRook) => return 'r',
                @intFromEnum(BitboardIdx.bQueen) => return 'q',
                @intFromEnum(BitboardIdx.bKing) => return 'k',
                else => return 'X',
            }
        }
    }
    return 'X';
}

fn parseGo(self: *Self, args: []const u8) !void{
    var tokens = std.mem.splitAny(u8, args, " ");
    const token = tokens.first();
    if(mem.eql(u8, token, "perft")){
        var opt: u2 = 0;
        while(tokens.next()) |arg|{
            if(mem.eql(u8, arg, "-divide")){
                opt = 1;
                continue;
            }
            const n = std.fmt.parseInt(u32, arg, 10) catch unreachable;
            if(opt == 0){
                for(1..n+1) |i|{
                    const start = Io.Clock.awake.now(self.io);           
                    
                    const res = perft.start(&self.board, @intCast(i), opt).?;
                    std.mem.doNotOptimizeAway(res);
                    const end = start.untilNow(self.io, .awake);

                    std.debug.print("peft depth {}: nodes {}, time {}s\n", .{i, res, @as(f64, @floatFromInt(end.toNanoseconds())) / @as(f64, 1000000000)});
                }        
            }else{
                _ = perft.start(&self.board, n, opt);
            }
      
            
        }

        return;
    }
    
    tokens.reset();

    var depth: u32 = default_search_depth;

    var wtime: i32 = 60000;

    var btime: i32 = 60000;

    const winc: i32 = 0;

    const binc: i32 = 0;

    const movetime: u32 = 0;


    // TODO: detect extra go arguments

    while(tokens.next()) |arg|{
        
        if(mem.eql(u8, arg, "depth")){
            if(tokens.next()) |d|{
                depth = std.fmt.parseInt(u32, d, 10) catch unreachable;
            }
        }
        if(mem.eql(u8, args, "wtime")){
            if(tokens.next()) |wt|{

                wtime = std.fmt.parseInt(i32, wt, 10) catch unreachable;
    
            }
        }
        if(mem.eql(u8, args, "btime")){
            if(tokens.next()) |bt|{

                btime = std.fmt.parseInt(i32, bt, 10) catch unreachable;

            }            
        }
    }

    std.debug.print("depth {}\n", .{depth});
    std.debug.print("wtime {}\n", .{wtime});
    std.debug.print("btime {}\n", .{btime});

    //std.debug.print("search info wtime {} btime {}\n", .{wtime, btime});

    const move = search.getBestMove(self.io,
                        &self.board, 
                        depth, 
                        wtime, 
                        btime, 
                        winc, 
                        binc, 
                        movetime); 
    
    try self.writer.print("bestmove {s}\n", .{move});
                        
}

fn parseMove(self: *Self, args: []const u8) void{
    var moves = self.board.generateMoves();
    const fileFrom: u10 = args[0] - 'a';
    const rankFrom: u10 = args[1] - '1';
    const from: u10 = rankFrom * 8 + fileFrom;

    const fileTo: u10 = args[2] - 'a';
    const rankTo: u10 = args[3] - '1';
    const to: u10 = rankTo * 8 + fileTo;

    const isPromotion: bool = if(args.len == 5) true else false;
    var promotionsAvailable: [5]u8 = undefined;
    var promotionCount: u3 = 0;

    var illegal: bool = true;

    for(0..moves.count) |i|{
        if(from == moves.moves[i].from and to == moves.moves[i].to and !isPromotion){
            self.board.makeMove(&moves.moves[i]);
            illegal = false;
            break;
        }else if(from == moves.moves[i].from and to == moves.moves[i].to and isPromotion){
            illegal = false;
            promotionsAvailable[promotionCount] = @intCast(i);
            promotionCount += 1;
            if(promotionCount == 5){
                break;
            }
        }
    }

    if(illegal){
        std.log.err("illegal move\n", .{});
    }

    if(isPromotion){
        for(0..promotionCount) |i|{
            if(args[4] == 'q' and (moves.moves[promotionsAvailable[i]].flags == .queenPromotion or 
                                    moves.moves[promotionsAvailable[i]].flags == .queenPromotionCapture)){
                self.board.makeMove(&moves.moves[promotionsAvailable[i]]);
            }else if(args[4] == 'r' and (moves.moves[promotionsAvailable[i]].flags == .rookPromotion or 
                                    moves.moves[promotionsAvailable[i]].flags == .rookPromotionCapture)){
                self.board.makeMove(&moves.moves[promotionsAvailable[i]]);                        
            }else if(args[4] == 'n' and (moves.moves[promotionsAvailable[i]].flags == .knightPromotion or 
                                    moves.moves[promotionsAvailable[i]].flags == .knightPromotionCapture)){
                self.board.makeMove(&moves.moves[promotionsAvailable[i]]);
            }else if(args[4] == 'b' and (moves.moves[promotionsAvailable[i]].flags == .bishopPromotion or 
                                    moves.moves[promotionsAvailable[i]].flags == .bishopPromotionCapture)){
                self.board.makeMove(&moves.moves[promotionsAvailable[i]]);
            }
        }
    }
}

fn parsePosition(self: *Self, args: []const u8) void{

    var tokens = std.mem.splitSequence(u8, args, " ");
    var valid = false;

    const farg = tokens.first();

    if(std.mem.eql(u8, farg, "startpos")){
        self.board.restartPos();
        valid = true;
    }else if(std.mem.eql(u8, farg, "fen")){
        var fen: Loc = undefined;
        //std.debug.print("{s}\n", .{args});
        fen.start = getToken(args, 1).start;
        fen.end =  getToken(args, 6).end;

        if(fen.end <= fen.start){
            return;
        }

        self.board.setPos(args[fen.start..fen.end]) catch {
            std.log.err("Invalid pos: {s}\n", .{args[fen.start..fen.end]});
        };

        for(0..6) |_|{
            _ = tokens.next().?;
        }

        valid = true;
    }

    if(tokens.next()) |movesArg|{
        //std.debug.print("move: {s}\n", .{movesArg});
        if(mem.eql(u8, movesArg, "moves") and valid){
            while(tokens.next()) |move|{
                //std.debug.print("move: {s}\n", .{move});
                self.parseMove(move);
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

pub fn moveToUcimove(move: Move) []u8{
    var buffer: [1024]u8 = @splat(0);

    if(@intFromEnum(move.flags) >= 6){

        var promotion: u8 = 0;
        switch (move.flags) {
            .bishopPromotion, .bishopPromotionCapture => {promotion = 'b';},
            .knightPromotion, .knightPromotionCapture => {promotion = 'k';},
            .rookPromotion, .rookPromotionCapture => {promotion = 'r';},
            .queenPromotion, .queenPromotionCapture => {promotion = 'q';},
            else => {},
        }

        return std.fmt.bufPrint(&buffer, "{s}{s}{c}", 
        .{
            squares[move.from], 
            squares[move.to],
            promotion,
            }) catch unreachable;
    }else{
        const slice =  std.fmt.bufPrint(&buffer, "{s}{s}", .{squares[move.from], squares[move.to]}) catch unreachable;
        //std.debug.print("slice {s}\n", .{slice});
        return slice;
    }
}

pub fn ucimove_to_move(move: []const u8) void{
    _ = move;
}