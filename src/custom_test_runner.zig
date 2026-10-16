const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;

var out_buf: [1024]u8 = undefined;
var stdout: Io.File.Writer = undefined;
var out: *Io.Writer = undefined;

pub fn main(init: std.process.Init) void{
    stdout = Io.File.stdout().writerStreaming(init.io, &out_buf);
    out = &stdout.interface;

    var success_counter: u32 = 0;
    var failure_counter: u32 = 0;

    for(builtin.test_functions) |t|{
        out.print("Test {s}\n", .{t.name}) catch {};
        out.flush() catch {};
        t.func() catch |err| {
            failure_counter += 1;
            out.print("Test '{s}'' failed. \n\t{}\n", .{t.name, err}) catch {};
            out.flush() catch {};

            if(@errorReturnTrace()) |trace|{
                std.debug.dumpErrorReturnTrace(trace);
            }

            continue;
        };

        success_counter += 1;

        out.print("Test {s} passed\n", .{t.name}) catch {};
        out.flush() catch {};
    }

    out.print("Tot test {}, passed {}, failed {}\n", .{success_counter + failure_counter, success_counter, failure_counter}) catch {};
    out.flush() catch {};
}

