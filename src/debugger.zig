const std = @import("std");

const ArrayList = std.ArrayList;

const Opcode = struct {
    name: []const u8 = "",
    opcode: u16 = 0,
    nnn: ?u12 = null,
    n: ?u4 = null,
    x: ?u4 = null,
    y: ?u4 = null,
    kk: ?u8 = null,
};

pub const Debugger = struct {
    const Self = @This();
    debugged_rom: ArrayList(Opcode),

    pub fn debugRom(rom_size: usize, rom: *[4096]u8, alloc: std.mem.Allocator) ?Self {
        var i: usize = 0;
        var debugged_rom = ArrayList(Opcode).init(alloc);
        while (i < rom_size) {
            i += 4;
            const opcode = (@as(u16, rom[i - 4]) << 8 | rom[i - 3]);
            debugged_rom.append(switch (opcode) {
                0x00E0 => .{
                    .name = "CLS",
                    .opcode = 0x00E0,
                },
                0x00EE => .{
                    .name = "RET",
                    .opcode = 0x00EE,
                },
                else => switch (opcode & 0xF000) {
                    0x1000 => .{
                        .name = "JP", //JP addr
                        .opcode = 0x1000,
                        .nnn = @intCast(u12, opcode & 0x0FFF),
                    },
                    0x2000 => .{
                        .name = "CALL", //CALL addr
                        .opcode = 0x2000,
                        .nnn = @intCast(u12, opcode & 0x0FFF),
                    },
                    0x3000 => .{
                        .name = "SE", //SE Vx, byte
                        .opcode = 0x3000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .kk = @intCast(u8, opcode & 0xFF),
                    },
                    0x4000 => .{
                        .name = "SNE", //SNE Vx, byte
                        .opcode = 0x4000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .kk = @intCast(u8, opcode & 0xFF),
                    },
                    0x5000 => .{
                        .name = "SE", //SE Vx, vy
                        .opcode = 0x5000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .y = @intCast(u4, (opcode >> 4) & 0x0F),
                    },
                    0x6000 => .{
                        .name = "LD", //LD Vx, byte
                        .opcode = 0x6000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .kk = @intCast(u8, opcode & 0xFF),
                    },
                    0x7000 => .{
                        .name = "ADD", //ADD Vx, byte
                        .opcode = 0x7000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .kk = @intCast(u8, opcode & 0xFF),
                    },
                    0x8000 => switch (opcode & 0x0F) {
                        0x00 => .{
                            .name = "LD", //LD Vx, Vy
                            .opcode = 0x8000,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x01 => .{
                            .name = "OR", //OR Vx, Vy
                            .opcode = 0x8001,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x02 => .{
                            .name = "AND", //AND Vx,Vy
                            .opcode = 0x8002,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x03 => .{
                            .name = "XOR", //XOR Vx, Vy
                            .opcode = 0x8003,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x04 => .{
                            .name = "ADD", //ADD Vx, Vy
                            .opcode = 0x8004,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x05 => .{
                            .name = "SUB", //SUB Vx, Vy
                            .opcode = 0x8005,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x06 => .{
                            .name = "SHR", //SHR Vx, Vy
                            .opcode = 0x8006,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x07 => .{
                            .name = "SUBN", //SUBN Vx, Vy
                            .opcode = 0x8007,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        0x0E => .{
                            .name = "SHL", //SHL Vx, Vy
                            .opcode = 0x800E,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                            .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        },
                        else => {
                            std.log.err("Illegal Opcode: {x}", .{opcode});
                            continue;
                        },
                    },
                    0x9000 => .{
                        .name = "SNE", //SNE Vx, vy
                        .opcode = 0x9000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .y = @intCast(u4, (opcode >> 4) & 0x0F),
                    },
                    0xA000 => .{
                        .name = "LD", //LD I, addr
                        .opcode = 0xA000,
                        .nnn = @intCast(u12, opcode & 0x0FFF),
                    },
                    0xB000 => .{
                        .name = "JP", //JP V0, addr
                        .opcode = 0xB000,
                        .nnn = @intCast(u12, opcode & 0x0FFF),
                    },
                    0xC000 => .{
                        .name = "RND", //RND Vx, byte
                        .opcode = 0xC000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .kk = @intCast(u8, opcode & 0xFF),
                    },
                    0xD000 => .{
                        .name = "DRW", //DRW Vx, Vy, nibble
                        .opcode = 0xD000,
                        .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        .y = @intCast(u4, (opcode >> 4) & 0x0F),
                        .n = @intCast(u4, opcode & 0x0F),
                    },
                    0xE000 => switch (opcode & 0xFF) {
                        0x9E => .{
                            .name = "SKP", //SKP Vx
                            .opcode = 0xE09E,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0xA1 => .{
                            .name = "SKNP", //SKNP Vx
                            .opcode = 0xE0A1,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        else => {
                            std.log.err("Illegal Opcode: {x}", .{opcode});
                            continue;
                        },
                    },
                    0xF000 => switch (opcode & 0xFF) {
                        0x07 => .{
                            .name = "LD", //LD Vx, DT
                            .opcode = 0xF007,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x0A => .{
                            .name = "LD", //LD Vx, K
                            .opcode = 0xF00A,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x15 => .{
                            .name = "LD", //LD DT, Vx
                            .opcode = 0xF015,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x18 => .{
                            .name = "LD", //LD ST, Vx
                            .opcode = 0xF018,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x1E => .{
                            .name = "ADD", //ADD I, Vx
                            .opcode = 0xF01E,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x29 => .{
                            .name = "LD", //LD F, Vx
                            .opcode = 0xF029,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x33 => .{
                            .name = "LD", //LD B, Vx
                            .opcode = 0xF033,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x55 => .{
                            .name = "LD", //LD I, Vx
                            .opcode = 0xF055,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        0x65 => .{
                            .name = "LD", //LD Vx, I
                            .opcode = 0xF065,
                            .x = @intCast(u4, (opcode >> 8) & 0x0F),
                        },
                        else => {
                            std.log.err("Illegal Opcode: {x}", .{opcode});
                            continue;
                        },
                    },
                    else => {
                        std.log.err("Illegal Opcode: {x}", .{opcode});
                        continue;
                    },
                },
            }) catch |err| {
                std.log.err("Getting Debug Symbols: {any}", .{err});
                debugged_rom.deinit();
                return null;
            };
        }
        return .{
            .debugged_rom = debugged_rom,
        };
    }

    pub fn deinit(self: *Self) void {
        self.debugged_rom.deinit();
    }
};
