const std = @import("std");

pub const Display = struct {
    const Self = @This();
    pixels: [64][32]u1 = [1][32]u1{[_]u1{0} ** 32} ** 64,

    pub fn set(self: *Self, x: u8, y: u8, pixel: u1) u1 {
        const re = self.pixels[x][y];
        self.pixels[x][y] ^= pixel;
        return re;
    }

    pub fn clear(self: *Self) void {
        self.pixels = [1][32]u1{[_]u1{0} ** 32} ** 64;
    }
};
