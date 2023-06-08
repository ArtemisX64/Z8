const std = @import("std");
const config = @import("config.zig");
const chip8 = @import("chip8.zig");
const raylib = @import("raylib");
const nfd = @import("nfd");

const Keys = [16]raylib.KeyboardKey{ raylib.KeyboardKey.KEY_ZERO, raylib.KeyboardKey.KEY_ONE, raylib.KeyboardKey.KEY_TWO, raylib.KeyboardKey.KEY_THREE, raylib.KeyboardKey.KEY_FOUR, raylib.KeyboardKey.KEY_FIVE, raylib.KeyboardKey.KEY_SIX, raylib.KeyboardKey.KEY_SEVEN, raylib.KeyboardKey.KEY_EIGHT, raylib.KeyboardKey.KEY_NINE, raylib.KeyboardKey.KEY_Q, raylib.KeyboardKey.KEY_B, raylib.KeyboardKey.KEY_C, raylib.KeyboardKey.KEY_D, raylib.KeyboardKey.KEY_W, raylib.KeyboardKey.KEY_S };

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Leak Detected... Failed to Deinitialising GPA", .{});
    };
    var cfg = config.Config.new(gpa.allocator());
    defer cfg.deinit();
    var c8 = chip8.Interpreter.new();
    defer c8.deinit();

    const game_path = nfd.openFileDialog("ch8", null) catch |err| {
        std.log.err("Loading File: {}", .{err});
        return;
    };
    if (game_path) |path| {
        c8.loadRom(path, gpa.allocator());
    }

    raylib.InitWindow(cfg.width * cfg.usr.win.multiplier, cfg.height * cfg.usr.win.multiplier, "Z8");
    defer raylib.CloseWindow();

    raylib.InitAudioDevice();
    defer raylib.CloseAudioDevice();

    const beep = raylib.LoadSound("utils/beep.wav");
    defer raylib.UnloadSound(beep);

    raylib.SetTargetFPS(cfg.usr.hacks.target_fps);

    while (c8.next() and !raylib.WindowShouldClose()) {
        if (c8.cpu.dt != 0 or c8.cpu.st != 0) {
            for (0..60) |_| {}
            if (c8.cpu.dt != 0) {
                c8.cpu.dt -= 1;
            }
            if (c8.cpu.st != 0) {
                c8.cpu.st -= 1;
                raylib.PlaySound(beep);
                std.time.sleep(500);
            }
        }
        raylib.BeginDrawing();
        defer raylib.EndDrawing();
        //raylib.DrawFPS(10, 10);

        raylib.ClearBackground(raylib.BLACK);
        raylib.PollInputEvents();
        for (c8.disp.pixels, 0..64) |row_pixel, x| {
            for (row_pixel, 0..32) |pixel, y| {
                if (pixel == 1) {
                    raylib.DrawRectangle(@intCast(i32, x) * cfg.usr.win.multiplier, @intCast(i32, y) * cfg.usr.win.multiplier, cfg.usr.win.multiplier, cfg.usr.win.multiplier, raylib.WHITE);
                }
            }
        }
        inline for (0..16) |i| {
            if (raylib.IsKeyDown(Keys[i])) {
                c8.keypad.press(@intCast(u8, i));
            } else if (raylib.IsKeyUp(Keys[i])) {
                c8.keypad.release(@intCast(u8, i));
            } else {
                c8.keypad.release(@intCast(u8, i));
            }
        }
    }
}
