const std = @import("std");
const Uci = @import("uci.zig");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const writer = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), init.io, &stdin_buffer);
    const reader = &stdin_file_reader.interface;

    var uci = Uci.Init(writer, reader, init.io);

    try uci.run();
}

