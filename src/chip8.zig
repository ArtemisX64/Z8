const std = @import("std");
const Rom = @import("load_rom.zig").Rom;
const Debugger = @import("debugger.zig").Debugger;
const Display = @import("display.zig").Display;
const Keypad = @import("keypad.zig").Keypad;

const Memory = struct {
    const Self = @This();
    start: u16 = 0x200,
    font_data: [80]u8,
    mem: [4096]u8,

    pub fn new() Self {
        const font_data = [_]u8{
            0xf0, 0x90, 0x90, 0x90, 0xf0, //0
            0x20, 0x60, 0x20, 0x20, 0x70, //1
            0xf0, 0x10, 0xf0, 0x80, 0xf0, //2
            0xf0, 0x10, 0xf0, 0x10, 0xf0, //3
            0x90, 0x90, 0xf0, 0x10, 0x10, //4
            0xf0, 0x80, 0xf0, 0x10, 0xf0, //5
            0xf0, 0x80, 0xf0, 0x90, 0xf0, //6
            0xf0, 0x10, 0x20, 0x40, 0x40, //7
            0xf0, 0x90, 0xf0, 0x90, 0xf0, //8
            0xf0, 0x90, 0xf0, 0x10, 0xf0, //9
            0xf0, 0x90, 0xf0, 0x90, 0x90, //A
            0xe0, 0x90, 0xe0, 0x90, 0xe0, //B
            0xf0, 0x80, 0x80, 0x80, 0xf0, //C
            0xe0, 0x90, 0x90, 0x90, 0xe0, //D
            0xf0, 0x80, 0xf0, 0x80, 0xf0, //E
            0xf0, 0x80, 0xf0, 0x80, 0x80, //F
        };

        return .{
            .mem = font_data ++ [_]u8{0} ** (4096 - font_data.len),
            .font_data = font_data,
        };
    }

    pub fn get_byte(self: *Self, pos: u16) u8 {
        return self.mem[pos];
    }
    pub fn get_2bytes(self: *Self, pos: u16) u16 {
        return @intCast(u16, self.get_byte(pos)) << 8 | self.get_byte(pos + 1);
    }

    pub fn set_byte(self: *Self, pos: u16, val: u8) void {
        self.mem[pos] = val;
    }

    pub fn set_2bytes(self: *Self, pos: u16, val: u16) void {
        self.set_byte(pos, @intCast(u8, (val >> 8) & 0xFF));
        self.set_byte(pos + 1, @intCast(u8, val & 0xFF));
    }
};

const Stack = struct {
    const Self = @This();
    stack: [16]u16,
    sp: u8,

    pub fn new() Self {
        return .{
            .stack = [_]u16{0} ** 16,
            .sp = 0,
        };
    }

    pub fn push(self: *Self, val: u16) void {
        self.stack[self.sp] = val;
        self.sp +|= 1;
    }

    pub fn pop(self: *Self) u16 {
        self.sp -|= 1;
        return self.stack[self.sp];
    }
};

const Cpu = struct {
    const Self = @This();
    v: [16]u8,
    i: u16,
    dt: u8,
    st: u8,
    pc: u16,
    stack: Stack,

    pub fn new() Self {
        return .{
            .v = [_]u8{0} ** 16,
            .i = 0,
            .dt = 0,
            .st = 0,
            .pc = 0x200,
            .stack = Stack.new(),
        };
    }
    pub fn reset(self: *Self) void {
        self.* = .{
            .v = [_]u8{0} ** 16,
            .i = 0,
            .dt = 0,
            .st = 0,
            .pc = 0x200,
            .stack = Stack.new(),
        };
    }
};

pub const Interpreter = struct {
    const Self = @This();
    cpu: Cpu,
    mem: Memory,
    rom: Rom,
    run: bool,
    debugger: ?Debugger,
    rnd_gen: std.rand.DefaultPrng,
    disp: Display,
    keypad: Keypad,

    pub fn new() Self {
        return .{
            .cpu = Cpu.new(),
            .mem = Memory.new(),
            .rom = Rom{},
            .run = false,
            .debugger = null,
            .rnd_gen = std.rand.DefaultPrng.init(@intCast(u64, std.time.timestamp())),
            .disp = .{},
            .keypad = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.debugger != null) {
            self.debugger.?.deinit();
        }
        self.cpu.reset();
        self.mem = Memory.new();
        self.rom = Rom{};
        self.run = false;
        self.debugger = null;
    }

    pub fn loadRom(self: *Self, rom_path: []const u8, alloc: ?std.mem.Allocator) void {
        self.rom.readRom(rom_path);
        if (!self.rom.rom_loaded) {
            return;
        }
        self.run = true;
        self.decodeRom(alloc);
        self.cpu.reset();
    }

    fn decodeRom(self: *Self, alloc: ?std.mem.Allocator) void {
        for (0..self.rom.rom_size) |i| {
            self.mem.mem[self.mem.start + i] = self.rom.rom[i];
        }
        if (alloc != null) {
            self.debugger = Debugger.debugRom(self.rom.rom_size, &self.rom.rom, alloc.?);
        }
    }

    pub fn next(self: *Self) bool {
        const opcode = self.fetchOpcode();
        switch (opcode) {
            0x00E0 => {
                self.disp.clear();
            },
            0x00EE => {
                self.cpu.pc = self.cpu.stack.pop();
            },
            else => switch (opcode & 0xF000) {
                0x1000 => {
                    const nnn = @intCast(u12, opcode & 0x0FFF);
                    self.cpu.pc = nnn;
                },
                0x2000 => {
                    const nnn = @intCast(u12, opcode & 0x0FFF);
                    self.cpu.stack.push(self.cpu.pc);
                    self.cpu.pc = nnn;
                },
                0x3000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const kk = @intCast(u8, opcode & 0xFF);
                    if (self.cpu.v[x] == kk) {
                        self.cpu.pc += 2;
                    }
                },
                0x4000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const kk = @intCast(u8, opcode & 0xFF);
                    if (self.cpu.v[x] != kk) {
                        self.cpu.pc += 2;
                    }
                },
                0x5000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const y = @intCast(u4, (opcode >> 4) & 0x0F);
                    if (self.cpu.v[x] == self.cpu.v[y]) {
                        self.cpu.pc += 2;
                    }
                },
                0x6000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const kk = @intCast(u8, opcode & 0xFF);
                    self.cpu.v[x] = kk;
                },
                0x7000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const kk = @intCast(u8, opcode & 0xFF);
                    self.cpu.v[x] +%= kk;
                },
                0x8000 => switch (opcode & 0x0F) {
                    0x00 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);
                        self.cpu.v[x] = self.cpu.v[y];
                    },
                    0x01 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);
                        self.cpu.v[x] |= self.cpu.v[y];
                    },
                    0x02 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);
                        self.cpu.v[x] &= self.cpu.v[y];
                    },
                    0x03 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);
                        self.cpu.v[x] ^= self.cpu.v[y];
                    },
                    0x04 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);
                        const sum = @addWithOverflow(self.cpu.v[x], self.cpu.v[y]);
                        self.cpu.v[x] = sum[0];
                        self.cpu.v[0x0F] = sum[1];
                    },
                    0x05 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);

                        self.cpu.v[0x0F] = @boolToInt(self.cpu.v[x] > self.cpu.v[y]);
                        self.cpu.v[x] -%= self.cpu.v[y];
                    },
                    0x06 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.v[0xF] = self.cpu.v[x] & 0x01;
                        self.cpu.v[x] >>= 1;
                    },
                    0x07 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        const y = @intCast(u4, (opcode >> 4) & 0x0F);
                        self.cpu.v[0x0F] = 0;
                        if (self.cpu.v[x] < self.cpu.v[y]) {
                            self.cpu.v[0x0F] = 1;
                        }
                        self.cpu.v[x] = self.cpu.v[y] -% self.cpu.v[x];
                    },
                    0x0E => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.v[0xF] = (self.cpu.v[x] >> 7) & 0x01;
                        self.cpu.v[x] <<= 1;
                    },
                    else => {
                        std.log.err("Illegal Opcode: {x}", .{opcode});
                        return false;
                    },
                },
                0x9000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const y = @intCast(u4, (opcode >> 4) & 0x0F);
                    if (self.cpu.v[x] != self.cpu.v[y]) {
                        self.cpu.pc += 2;
                    }
                },
                0xA000 => {
                    const nnn = @intCast(u12, opcode & 0x0FFF);
                    self.cpu.i = nnn;
                },
                0xB000 => {
                    const nnn = @intCast(u12, opcode & 0x0FFF);
                    self.cpu.pc = nnn + self.cpu.v[0x00];
                },
                0xC000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const kk = @intCast(u8, opcode & 0xFF);
                    self.cpu.v[x] = kk & self.rnd_gen.random().uintAtMost(u8, 0xFF);
                },
                0xD000 => {
                    const x = @intCast(u4, (opcode >> 8) & 0x0F);
                    const y = @intCast(u4, (opcode >> 4) & 0x0F);
                    const n = @intCast(u4, opcode & 0x0F);
                    for (0..n) |j| {
                        const pixel = self.mem.mem[j + self.cpu.i];
                        for (0..8) |i| {
                            self.cpu.v[0x0F] = self.disp.set(@intCast(u8, (self.cpu.v[x] + @intCast(u8, i)) % 64), @intCast(u8, (self.cpu.v[y] + @intCast(u16, j)) % 32), @intCast(u1, (pixel >> @intCast(u3, 7 - i)) & 0x01));
                        }
                    }
                },
                0xE000 => switch (opcode & 0xFF) {
                    0x9E => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        if (self.keypad.get(self.cpu.v[x]) == 1) {
                            self.cpu.pc += 2;
                        }
                    },
                    0xA1 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        if (self.keypad.get(self.cpu.v[x]) == 0) {
                            self.cpu.pc += 2;
                        }
                    },
                    else => {
                        std.log.err("Illegal Opcode: {x}", .{opcode});
                        return false;
                    },
                },
                0xF000 => switch (opcode & 0xFF) {
                    0x07 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.v[x] = self.cpu.dt;
                    },
                    0x0A => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        for (0..16) |i| {
                            if (self.keypad.keys[i] == 1) {
                                self.cpu.v[x] = @intCast(u8, i);
                                return true;
                            }
                        }
                        self.cpu.pc -= 2;
                    },
                    0x15 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.dt = self.cpu.v[x];
                    },
                    0x18 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.st = self.cpu.v[x];
                    },
                    0x1E => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.i += self.cpu.v[x];
                    },
                    0x29 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.cpu.i = self.cpu.v[x] * 5;
                    },
                    0x33 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        self.mem.set_byte(self.cpu.i, @divFloor(self.cpu.v[x], 100));
                        self.mem.set_byte(self.cpu.i + 1, @divFloor(self.cpu.v[x] % 100, 10));
                        self.mem.set_byte(self.cpu.i + 2, self.cpu.v[x] % 10);
                    },
                    0x55 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        for (0..x +| 1) |i| {
                            self.mem.mem[self.cpu.i + i] = self.cpu.v[i];
                        }
                    },
                    0x65 => {
                        const x = @intCast(u4, (opcode >> 8) & 0x0F);
                        for (0..x +| 1) |i| {
                            self.cpu.v[i] = self.mem.mem[self.cpu.i + i];
                        }
                    },
                    else => {
                        std.log.err("Illegal Opcode: {x}", .{opcode});
                        return false;
                    },
                },
                else => {
                    std.log.err("Illegal Opcode: {x}", .{opcode});
                    return false;
                },
            },
        }
        return true;
    }

    fn fetchOpcode(self: *Self) u16 {
        self.cpu.pc += 2;
        return self.mem.get_2bytes(self.cpu.pc - 2);
    }
};
