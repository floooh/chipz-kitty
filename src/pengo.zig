const std = @import("std");
const vaxis = @import("vaxis");
const zigimg = vaxis.zigimg;
const namco = @import("chipz").systems.namco;

const Pengo = namco.Type(.Pengo);

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    winsize: vaxis.Winsize,
};

var sys: Pengo = undefined;
// not a bug, since screen is in portrait mode
const src_width = Pengo.displayInfo(null).view.width;
const src_height = Pengo.displayInfo(null).view.height;
const dst_width = src_height;
const dst_height = src_width;
const bytes_per_pixel = 3;
var rgb_buffer: [dst_width * dst_height * bytes_per_pixel]u8 = undefined;

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

    var ev_loop = vaxis.Loop(Event){ .tty = &tty, .vaxis = &vx };
    try ev_loop.init();
    try ev_loop.start();
    defer ev_loop.stop();

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

    // frame loop
    var running = true;
    var t = std.time.microTimestamp();
    while (running) {
        const win = vx.window();
        if (win.screen.width == 0) {
            while (ev_loop.tryEvent()) |ev| {
                switch (ev) {
                    .winsize => |ws| try vx.resize(alloc, tty.anyWriter(), ws),
                    else => {},
                }
            }
            continue;
        }

        const t1 = std.time.microTimestamp();
        const frame_time_us = std.math.clamp(t1 - t, 1000, 24000);
        t = t1;
        _ = sys.exec(@intCast(frame_time_us));

        var pixels = zigimg.Image{
            .width = dst_width,
            .height = dst_height,
            .pixels = try zigimg.color.PixelStorage.initRawPixels(&rgb_buffer, .rgb24),
        };
        const img = try vx.transmitImage(alloc, tty.anyWriter(), &pixels, .rgb);

        // convert framebuffer pixels (this also does the landscape-portrait rotation)
        const disp_info = sys.displayInfo();
        const pal = disp_info.palette.?;
        const src_pitch: usize = @intCast(disp_info.fb.dim.width);
        const src: []const u8 = disp_info.fb.buffer.?.Palette8;
        var idx: usize = 0;
        for (0..src_width) |x| {
            for (0..src_height) |y| {
                const p: u8 = src[(src_height - 1 - y) * src_pitch + x];
                const c = pal[p];
                const r: u8 = @truncate(c);
                const g: u8 = @truncate(c >> 8);
                const b: u8 = @truncate(c >> 16);
                rgb_buffer[idx] = r;
                idx += 1;
                rgb_buffer[idx] = g;
                idx += 1;
                rgb_buffer[idx] = b;
                idx += 1;
            }
        }

        try img.draw(win, .{});

        while (ev_loop.tryEvent()) |ev| {
            switch (ev) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true })) {
                        running = false;
                    }
                },
                .winsize => |ws| try vx.resize(alloc, ev_loop.tty.anyWriter(), ws),
                else => {},
            }
        }

        try vx.render(tty.anyWriter());

        std.time.sleep(16_666_667);
    }
}

fn dummyAudioCallback(samples: []const f32) void {
    _ = samples;
}
