const std = @import("std");
const raylib = @import("libs/raylib/build.zig");
const nfd_build = @import("libs/nfd-zig/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "z8",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const nfd = b.addModule("nfd", .{ .source_file = .{ .path = "libs/nfd-zig/src/lib.zig" } });

    const lib = b.addStaticLibrary(.{
        .name = "nfd",
        .root_source_file = .{ .path = "libs/nfd-zig/src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.setMainPkgPath(".");
    lib.addModule("nfd", nfd);

    const cflags = [_][]const u8{"-Wall"};
    lib.addIncludePath("libs/nfd-zig/nativefiledialog/src/include");
    lib.addCSourceFile("libs/nfd-zig/nativefiledialog/src/nfd_common.c", &cflags);
    if (lib.target.isDarwin()) {
        lib.addCSourceFile("libs/nfd-zig/nativefiledialog/src/nfd_cocoa.m", &cflags);
    } else if (lib.target.isWindows()) {
        lib.addCSourceFile("libs/nfd-zig/nativefiledialog/src/nfd_win.cpp", &cflags);
    } else {
        lib.addCSourceFile("libs/nfd-zig/nativefiledialog/src/nfd_gtk.c", &cflags);
    }

    lib.linkLibC();
    if (lib.target.isDarwin()) {
        lib.linkFramework("AppKit");
    } else if (lib.target.isWindows()) {
        lib.linkSystemLibrary("shell32");
        lib.linkSystemLibrary("ole32");
        lib.linkSystemLibrary("uuid"); // needed by MinGW
    } else {
        lib.linkSystemLibrary("atk-1.0");
        lib.linkSystemLibrary("gdk-3");
        lib.linkSystemLibrary("gtk-3");
        lib.linkSystemLibrary("glib-2.0");
        lib.linkSystemLibrary("gobject-2.0");
    }
    lib.installHeadersDirectory("libs/nfd-zig/nativefiledialog/src/include", ".");
    b.installArtifact(lib);

    raylib.addTo(b, exe, target, optimize);
    exe.addIncludePath("libs/nfd-zig/nativefiledialog/src/include");
    exe.addModule("nfd", nfd);
    exe.linkLibrary(lib);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
