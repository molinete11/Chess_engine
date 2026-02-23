const std = @import("std");

pub fn build(b: *std.Build) void{

    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
            .name = "Chess_engine",
            .root_module = b.createModule(.{ 
                .root_source_file = b.path("src/main.zig"),
                .target = b.graph.host,
                .optimize = optimize,
            }),
        });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Running chess engine");
    run_step.dependOn(&run_exe.step);
}