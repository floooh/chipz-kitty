## chipz in the terminal

A little proof-of-concept to run an 8-bit emulator in a terminal
via the Kitty Graphics Protocol:

![image](screenshots/pengo_kitty.webp)

Tested in Ghostty and Kitty on macOS.

## Build and Run

Currently requires `Zig 0.13.0` (because of libvaxis depenency).

In Ghostty or Kitty:

```
zig build --release=fast run-pengo
```

Then press `1` to insert a coin, and press `Enter` to start.

In the game: arrow keys for direction and `Space` to push an ice block.

## Dependencies:

- [libvaxis](https://github.com/rockorager/libvaxis) for rendering
- [chipz](https://github.com/floooh/chipz) for the emulator core
- [sokol-audio](https://github.com/floooh/sokol-zig) for the sound

## References:

Uses code snippets from:

- https://github.com/cryptocode/terminal-doom

Kitty Graphics Protocol:

- https://sw.kovidgoyal.net/kitty/graphics-protocol/

Ghostty:

- https://ghostty.org/
