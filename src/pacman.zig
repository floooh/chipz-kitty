const std = @import("std");
const Key = @import("vaxis").Key;
const namco = @import("chipz").systems.namco;
const host = @import("host.zig");

const Pacman = namco.Type(.Pacman);

var sys: Pacman = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) {
        @panic("Memory leaks detected!");
    };
    try host.init(.{
        .allocator = gpa.allocator(),
        .key_cb = onKey,
    });
    defer host.deinit();

    sys.initInPlace(.{
        .audio = .{
            .sample_rate = host.audioSampleRate(),
            .callback = host.pushAudio,
        },
        .roms = .{
            .sys_0000_0FFF = @embedFile("roms/pacman/pacman.6e"),
            .sys_1000_1FFF = @embedFile("roms/pacman/pacman.6f"),
            .sys_2000_2FFF = @embedFile("roms/pacman/pacman.6h"),
            .sys_3000_3FFF = @embedFile("roms/pacman/pacman.6j"),
            .gfx_0000_0FFF = @embedFile("roms/pacman/pacman.5e"),
            .gfx_1000_1FFF = @embedFile("roms/pacman/pacman.5f"),
            .prom_0000_001F = @embedFile("roms/pacman/82s123.7f"),
            .prom_0020_011F = @embedFile("roms/pacman/82s126.4a"),
            .sound_0000_00FF = @embedFile("roms/pacman/82s126.1m"),
            .sound_0100_01FF = @embedFile("roms/pacman/82s126.3m"),
        },
    });

    // frame loop
    while (try host.pollEvents()) {
        _ = sys.exec(host.frameTimeMicroSeconds());
        try host.drawFrame(sys.displayInfo());
    }
}

fn onKey(pressed: bool, key: Key) void {
    const inp: Pacman.Input = switch (key.codepoint) {
        Key.left => .{ .p1_left = true },
        Key.right => .{ .p1_right = true },
        Key.up => .{ .p1_up = true },
        Key.down => .{ .p1_down = true },
        Key.space => .{ .p1_button = true },
        Key.f1, '1' => .{ .p1_coin = true },
        Key.f2, '2' => .{ .p2_coin = true },
        else => .{ .p1_start = true },
    };
    if (pressed) {
        sys.setInput(inp);
    } else {
        sys.clearInput(inp);
    }
}
