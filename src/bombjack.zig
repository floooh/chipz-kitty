const std = @import("std");
const Key = @import("vaxis").Key;
const Bombjack = @import("chipz").systems.bombjack.Bombjack;
const host = @import("host.zig");

var sys: Bombjack = undefined;

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
            .main_0000_1FFF = @embedFile("roms/bombjack/09_j01b.bin"),
            .main_2000_3FFF = @embedFile("roms/bombjack/10_l01b.bin"),
            .main_4000_5FFF = @embedFile("roms/bombjack/11_m01b.bin"),
            .main_6000_7FFF = @embedFile("roms/bombjack/12_n01b.bin"),
            .main_C000_DFFF = @embedFile("roms/bombjack/13.1r"),
            .sound_0000_1FFF = @embedFile("roms/bombjack/01_h03t.bin"),
            .chars_0000_0FFF = @embedFile("roms/bombjack/03_e08t.bin"),
            .chars_1000_1FFF = @embedFile("roms/bombjack/04_h08t.bin"),
            .chars_2000_2FFF = @embedFile("roms/bombjack/05_k08t.bin"),
            .tiles_0000_1FFF = @embedFile("roms/bombjack/06_l08t.bin"),
            .tiles_2000_3FFF = @embedFile("roms/bombjack/07_n08t.bin"),
            .tiles_4000_5FFF = @embedFile("roms/bombjack/08_r08t.bin"),
            .sprites_0000_1FFF = @embedFile("roms/bombjack/16_m07b.bin"),
            .sprites_2000_3FFF = @embedFile("roms/bombjack/15_l07b.bin"),
            .sprites_4000_5FFF = @embedFile("roms/bombjack/14_j07b.bin"),
            .maps_0000_0FFF = @embedFile("roms/bombjack/02_p04t.bin"),
        },
    });

    // frame-loop
    while (try host.pollEvents()) {
        _ = sys.exec(host.frameTimeMicroSeconds());
        try host.drawFrame(sys.displayInfo());
    }
}

fn onKey(pressed: bool, key: Key) void {
    const inp: Bombjack.Input = switch (key.codepoint) {
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
