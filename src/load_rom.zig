const std = @import("std");
const File = std.fs.File;

pub const Rom = struct {
    const Self = @This();
    rom: [4096]u8 = [_]u8{0} ** 4096,
    rom_size: u16 = 0,
    rom_loaded: bool = false,

    pub fn readRom(self: *Self, path: []const u8) void {
        if (self.rom_loaded) {
            self.rom = [_]u8{0} ** 4096;
            self.rom_size = 0;
        }

        const file = std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch |err| {
            std.log.err("Loading Rom: {any}", .{err});
            return;
        };
        const rom_size = file.readAll(&self.rom) catch |err| {
            std.log.err("Reading Rom: {any}", .{err});
            return;
        };
        self.rom_size = @intCast(u16, rom_size);
        self.rom_loaded = true;
    }

    pub fn deinit(self: *Self) void {
        self.rom = [_]u8{0} ** 4096;
        self.rom_size = 0;
        self.rom_loaded = false;
    }
};
