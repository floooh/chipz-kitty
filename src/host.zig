const std = @import("std");
const chipz = @import("chipz");
const vaxis = @import("vaxis");
const sokol = @import("sokol");
const saudio = sokol.audio;
const assert = std.debug.assert;
const DisplayInfo = chipz.common.glue.DisplayInfo;
const Window = vaxis.Window;
const Image = vaxis.Image;
const CellSize = Image.CellSize;
const zigimg = vaxis.zigimg;

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    winsize: vaxis.Winsize,
};

const KeyCallback = fn (down: bool, key: vaxis.Key) void;

pub const InitOptions = struct {
    allocator: std.mem.Allocator,
    key_cb: *const KeyCallback,
    disable_audio: bool = false,
};

const max_width = 512;
const max_height = 512;

var initialized = false;
var allocator: std.mem.Allocator = undefined;
var key_cb: *const KeyCallback = undefined;
var tty: vaxis.Tty = undefined;
var vx: vaxis.Vaxis = undefined;
var ev_loop: vaxis.Loop(Event) = undefined;
var width = undefined;
var height = undefined;
var max_rgba_buffer: [max_width * max_height]u32 = undefined;
var last_time: i64 = undefined;
var disable_audio = false;

pub fn init(opts: InitOptions) !void {
    assert(!initialized);
    allocator = opts.allocator;
    key_cb = opts.key_cb;
    disable_audio = opts.disable_audio;

    if (!disable_audio) {
        saudio.setup(.{});
    }

    tty = try vaxis.Tty.init();
    errdefer tty.deinit();

    vx = try vaxis.init(allocator, .{
        .kitty_keyboard_flags = .{
            .report_events = true,
        },
    });
    errdefer vx.deinit(allocator, tty.anyWriter());

    ev_loop = vaxis.Loop(Event){ .tty = &tty, .vaxis = &vx };
    try ev_loop.init();
    try ev_loop.start();
    errdefer ev_loop.stop();

    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminal(tty.anyWriter(), 1 * std.time.ns_per_s);

    last_time = std.time.microTimestamp();
    initialized = true;
}

pub fn deinit() void {
    assert(initialized);
    ev_loop.stop();
    vx.deinit(allocator, tty.anyWriter());
    tty.deinit();
    initialized = false;
    if (!disable_audio) {
        saudio.shutdown();
    }
}

pub fn audioSampleRate() u32 {
    assert(initialized);
    if (disable_audio) {
        return 44100;
    } else {
        return @intCast(saudio.sampleRate());
    }
}

pub fn pushAudio(samples: []const f32) void {
    assert(initialized);
    if (!disable_audio) {
        _ = saudio.push(&samples[0], @intCast(samples.len));
    }
}

pub fn drawFrame(display_info: DisplayInfo) !void {
    assert(initialized);

    const win = vx.window();
    if (win.screen.width == 0) {
        while (ev_loop.tryEvent()) |ev| {
            switch (ev) {
                .winsize => |ws| try vx.resize(allocator, tty.anyWriter(), ws),
                else => {},
            }
        }
        return;
    }

    const info = display_info;
    const landscape = info.orientation == .Landscape;

    const src_width: usize = @intCast(info.view.width);
    const src_height: usize = @intCast(info.view.height);
    assert(src_width <= max_width);
    assert(src_height <= max_height);
    const dst_width = if (landscape) src_width else src_height;
    const dst_height = if (landscape) src_height else src_width;
    const dst_size = dst_width * dst_height;
    const dst = max_rgba_buffer[0..dst_size];

    // convert framebuffer (including landscape => portrait rotation)
    if (info.palette) |palette| {
        // framebuffer is 8-bit palettized format (8-bit indices into 32-bit RGBA palette)
        const src: []const u8 = info.fb.buffer.?.Palette8;
        const src_pitch: usize = @intCast(info.fb.dim.width);
        var idx: usize = 0;
        for (0..src_width) |x| {
            for (0..src_height) |y| {
                const p: u8 = src[(src_height - 1 - y) * src_pitch + x];
                dst[idx] = palette[p];
                idx += 1;
            }
        }
    } else {
        // framebuffer is already in RGBA8
        const src: []const u32 = info.fb.buffer.?.Rgba8;
        const src_pitch: usize = @intCast(info.fb.dim.width);
        var idx: usize = 0;
        for (0..src_width) |x| {
            for (0..dst_height) |y| {
                const c = src[(src_height - 1 - y) * src_pitch + x];
                dst[idx] = c;
                idx += 1;
            }
        }
    }

    // workaround for compile error 'TODO: implement @ptrCast between slices changing the length'
    // e.g. we want a []u8 view on the [_]u32 pixel data array
    const dst_u8 = @as([*]u8, @ptrCast(dst))[0 .. dst.len * 4];
    var pixels = zigimg.Image{
        .width = dst_width,
        .height = dst_height,
        .pixels = try zigimg.color.PixelStorage.initRawPixels(dst_u8, .rgba32),
    };
    const img = try vx.transmitImage(allocator, tty.anyWriter(), &pixels, .rgba);

    // compute draw-size in cells keeping aspect ratio
    const draw_size = computeDrawSize(win, img, try img.cellSize(win));
    try img.draw(win, .{
        .size = .{
            .rows = draw_size.rows,
            .cols = draw_size.cols,
        },
    });
    try vx.render(tty.anyWriter());

    // NOTE: waiting a couple of millisecs here seems to help with
    // Ghostty not occupying 100% CPU (at least on macOS)
    std.time.sleep(4_000_000);
}

pub fn pollEvents() !bool {
    assert(initialized);
    var running = true;
    while (ev_loop.tryEvent()) |ev| {
        switch (ev) {
            .key_press, .key_release => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    running = false;
                } else {
                    key_cb(ev == .key_press, key);
                }
            },
            .winsize => |ws| {
                try vx.resize(allocator, ev_loop.tty.anyWriter(), ws);
            },
        }
    }
    return running;
}

pub fn frameTimeMicroSeconds() u32 {
    assert(initialized);
    const cur_time = std.time.microTimestamp();
    const frame_time = std.math.clamp(cur_time - last_time, 1000, 24000);
    last_time = cur_time;
    return @intCast(frame_time);
}

fn computeDrawSize(win: Window, img: Image, cell_size: CellSize) CellSize {
    const x_pix: f32 = @floatFromInt(win.screen.width_pix);
    const y_pix: f32 = @floatFromInt(win.screen.height_pix);
    const w: f32 = @floatFromInt(win.screen.width);
    const h: f32 = @floatFromInt(win.screen.height);
    const pix_per_col = x_pix / w;
    const pix_per_row = y_pix / h;
    const img_width: f32 = @floatFromInt(img.width);
    const img_height: f32 = @floatFromInt(img.height);
    const aspect_ratio = img_width / img_height;

    // calculate the maximum allowed width and height based on window dimensions
    const max_width_cells = @max(w, @as(f32, @floatFromInt(cell_size.cols)));
    const max_height_cells = h;

    // calculate the pixel dimensions for the max width and height
    const max_width_pix = max_width_cells * pix_per_col;
    const max_height_pix = max_height_cells * pix_per_row;

    var final_width_pix: f32 = 0;
    var final_height_pix: f32 = 0;

    // Scale according to the most limiting direction
    if (max_width_pix / aspect_ratio <= max_height_pix) {
        final_width_pix = max_width_pix;
        final_height_pix = final_width_pix / aspect_ratio;
    } else {
        final_height_pix = max_height_pix;
        final_width_pix = final_height_pix * aspect_ratio;
    }

    const final_width_cells = final_width_pix / pix_per_col;
    const final_height_cells = final_height_pix / pix_per_row;

    return .{
        .rows = @intFromFloat(final_height_cells),
        .cols = @intFromFloat(final_width_cells),
    };
}
