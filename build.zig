const std = @import("std");
const Build = std.Build;
const Module = Build.Module;
const Import = Build.Module.Import;
const ResolvedTarget = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_chipz = b.dependency("chipz", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const dep_vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const imports = [_]Import{
        .{ .name = "chipz", .module = dep_chipz.module("chipz") },
        .{ .name = "vaxis", .module = dep_vaxis.module("vaxis") },
        .{ .name = "sokol", .module = dep_sokol.module("sokol") },
    };

    addEmulator(b, .{
        .name = "pengo",
        .root_source_file = "src/pengo.zig",
        .imports = &imports,
        .target = target,
        .optimize = optimize,
    });
    addEmulator(b, .{
        .name = "pacman",
        .root_source_file = "src/pacman.zig",
        .imports = &imports,
        .target = target,
        .optimize = optimize,
    });
    addEmulator(b, .{
        .name = "bombjack",
        .root_source_file = "src/bombjack.zig",
        .imports = &imports,
        .target = target,
        .optimize = optimize,
    });
}

const EmulatorOptions = struct {
    name: []const u8,
    root_source_file: []const u8,
    imports: []const Import,
    target: ResolvedTarget,
    optimize: OptimizeMode,
};

fn addEmulator(b: *Build, opts: EmulatorOptions) void {
    const exe = b.addExecutable(.{
        .name = opts.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(opts.root_source_file),
            .target = opts.target,
            .optimize = opts.optimize,
            .imports = opts.imports,
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step(b.fmt("run-{s}", .{opts.name}), b.fmt("Run {s}", .{opts.name}));
    run_step.dependOn(&run_cmd.step);
}
