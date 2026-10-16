const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const File = Io.File;
const Allocator = mem.Allocator;


const Self = @This();

io: Io,
stdin_buffer: [1024]u8,
stdout_buffer: [1024]u8,

stdout: File.Writer,
stdin: File.Reader,

pub fn init(io: Io, allocator: Allocator) !*Self{
    var ret = try allocator.create(Self);
    
    ret.io = io;
    ret.stdin_buffer = @splat(0);
    ret.stdout_buffer = @splat(0);
    ret.stdout = undefined;
    ret.stdin = undefined;

    ret.stdout = File.stdout().writerStreaming(ret.io, &ret.stdout_buffer);
    ret.stdin = File.stdin().readerStreaming(ret.io, &ret.stdin_buffer);

    return ret;
}

pub fn printLn(self: *Self, comptime fmt: []const u8, args: anytype) !void{
    try self.stdout.interface.print(fmt ++ "\n", args);
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void{
    try self.stdout.interface.print(fmt, args);
}

pub fn flush(self: *Self) !void{
    try self.stdout.flush();
}

pub fn readLn(self: *Self, allocator: Allocator) ![]u8{
    var w = Io.Writer.Allocating.init(allocator);
    defer w.deinit();

    _ = try self.stdin.interface.streamDelimiterEnding(&w.writer, '\n');    
    _ = self.stdin.interface.takeByte() catch |err| switch (err) {
        error.EndOfStream => {},
        else => return err
    }; // skip '\n'
    return try w.toOwnedSlice();
}
