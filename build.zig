const std = @import("std");

pub fn build(b: *std.Build) void{
    
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});


    const exe = b.addExecutable(.{ 
        .name = "Muu",
        .use_llvm = true,
        .root_module = b.createModule(.{
            .optimize = optimize,
            .target = target,
            .root_source_file = b.path("src/main.zig"),
        }),
    });

    const tests = b.addTest(.{
        .use_llvm = true,
        .root_module = b.createModule(.{
            .optimize = optimize,
            .target = target,
            .root_source_file = b.path("src/board.zig"),
        }),
        .test_runner = .{
            .path = b.path("src/custom_test_runner.zig"),
            .mode = .simple,
        },
    });


    b.installArtifact(exe);

    const step_exe = b.addRunArtifact(exe);
    
    const run_step = b.step("run", "run the chess engine");

    run_step.dependOn(&step_exe.step);

    const test_step_run = b.addRunArtifact(tests);

    const test_step = b.step("test", "run all the tests");
    test_step.dependOn(&test_step_run.step);

}   