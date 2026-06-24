const std = @import("std");

pub fn build(b: *std.Build) void{

    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const perft_test = b.addTest(.{
        .name = "perft_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/perft.zig"),
            .target = target,
            .optimize = optimize,
        })
    });

    const run_preft = b.addRunArtifact(perft_test);

    const test_perft_step = b.step("test_perft", "running perft checks");
    test_perft_step.dependOn(&run_preft.step);

    const exe = b.addExecutable(.{
            .name = "Muu",
            .root_module = b.createModule(.{ 
                .root_source_file = b.path("src/main.zig"),
                .target = b.graph.host,
                .optimize = optimize,
                .single_threaded = true,
            }),
        });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Running chess engine");
    run_step.dependOn(&run_exe.step);
}