pub const Keypad = struct {
    const Self = @This();
    keys: [16]u1 = [_]u1{0} ** 16,
    pub fn get(self: *Self, key: u8) u1 {
        return self.keys[key];
    }
    pub fn press(self: *Self, key: u8) void {
        self.keys[key] = 1;
    }
    pub fn release(self: *Self, key: u8) void {
        self.keys[key] = 0;
    }
};
