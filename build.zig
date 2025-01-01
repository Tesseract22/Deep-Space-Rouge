const std = @import("std");
// const rl = @import("raylib/build.zig");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});



    const exe = b.addExecutable(.{
        .name = "game",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const rl = b.dependency("raylib", .{});
    exe.addIncludePath(rl.path("src"));
    exe.linkLibrary(rl.artifact("raylib"));
    exe.linkLibC();
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.addIncludePath(rl.path("src"));
    tests.linkLibrary(rl.artifact("raylib"));
    tests.linkLibC();
    b.installArtifact(tests);

    // This *creates* a Run step in the build graph, to be testscuted when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const test_cmd = b.addRunArtifact(tests);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    test_cmd.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "test the app");
    test_step.dependOn(&test_cmd.step);

}
