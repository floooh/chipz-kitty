const std = @import("std");
const vaxis = @import("vaxis");
const namco = @import("chipz").systems.namco;

const Pengo = namco.Type(.Pengo);

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    winsize: vaxis.Winsize,
};

var sys: Pengo = undefined;

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    var tty = try vaxis.Tty.init();
    defer tty.deinit();

    var vx = try vaxis.init(alloc, .{
        .kitty_keyboard_flags = .{
            .report_events = true,
        },
    });
    defer vx.deinit(alloc, tty.anyWriter());

    var event_loop = vaxis.Loop(Event){ .tty = &tty, .vaxis = &vx };
    try event_loop.init();
    try event_loop.start();
    defer event_loop.stop();

    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminal(tty.anyWriter(), 1 * std.time.ns_per_s);

    sys.initInPlace(.{
        // FIXME: audio
        .audio = .{
            .sample_rate = 44100,
            .callback = dummyAudioCallback,
        },
        .roms = .{
            .sys_0000_0FFF = @embedFile("roms/pengo/ep5120.8"),
            .sys_1000_1FFF = @embedFile("roms/pengo/ep5121.7"),
            .sys_2000_2FFF = @embedFile("roms/pengo/ep5122.15"),
            .sys_3000_3FFF = @embedFile("roms/pengo/ep5123.14"),
            .sys_4000_4FFF = @embedFile("roms/pengo/ep5124.21"),
            .sys_5000_5FFF = @embedFile("roms/pengo/ep5125.20"),
            .sys_6000_6FFF = @embedFile("roms/pengo/ep5126.32"),
            .sys_7000_7FFF = @embedFile("roms/pengo/ep5127.31"),
            .gfx_0000_1FFF = @embedFile("roms/pengo/ep1640.92"),
            .gfx_2000_3FFF = @embedFile("roms/pengo/ep1695.105"),
            .prom_0000_001F = @embedFile("roms/pengo/pr1633.78"),
            .prom_0020_041F = @embedFile("roms/pengo/pr1634.88"),
            .sound_0000_00FF = @embedFile("roms/pengo/pr1635.51"),
            .sound_0100_01FF = @embedFile("roms/pengo/pr1636.70"),
        },
    });
}

fn dummyAudioCallback(samples: []const f32) void {
    _ = samples;
}
