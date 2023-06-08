const std = @import("std");
const Allocator = std.mem.Allocator;

const Window = struct {
    multiplier: u16 = 10,
};
const Hacks = struct {
    target_fps: u16 = 60,
};

//has values that can be edited by user and controlled by config.json file
const UserConfig = struct {
    win: Window = .{},
    hacks: Hacks = .{},
};

pub const Config = struct {
    const Self = @This();
    width: u16 = 64,
    height: u16 = 32,
    title: [:0]const u8 = "Z8 emulator",
    usr: UserConfig,
    usr_file: ?std.fs.File,
    alloc: Allocator,

    //Creates a struct Config
    pub fn new(alloc: Allocator) Config {
        const default_config = .{
            .alloc = alloc,
            .usr = .{},
            .usr_file = null,
        };
        const config = readConfig() orelse return default_config;
        const user_config = parseConfig(alloc, &config);

        return .{
            .alloc = alloc,
            .usr = user_config,
            .usr_file = config,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.usr_file != null) {
            self.usr_file.?.close();
        }
    }

    fn parseConfig(alloc: Allocator, file: *const std.fs.File) UserConfig {
        var buffer = std.ArrayList(u8).init(alloc);
        defer buffer.deinit();
        const contents = file.reader().readAllAlloc(alloc, 4096) catch |err| {
            std.log.err("Reading File: {any}", .{err});
            return .{};
        };
        defer alloc.free(contents);

        return std.json.parseFromSlice(UserConfig, alloc, contents, .{}) catch ret: {
            std.log.warn("Parsing File. Trying Populating", .{});
            std.json.stringify(UserConfig{}, .{ .whitespace = .{ .indent = .{ .space = 4 } } }, buffer.writer()) catch |err| {
                std.log.err("Error Populating Json File: {any}", .{err});

                break :ret .{};
            };
            file.writeAll(buffer.items) catch |err| {
                std.log.err("Writing to file: {any}", .{err});
            };
            buffer.clearAndFree();
            break :ret .{};
        };
    }

    pub fn saveConfig(self: *Self) bool {
        var buffer = std.ArrayList(u8).init(self.alloc);
        defer buffer.deinit();
        std.json.stringify(UserConfig{}, .{ .whitespace = .{ .indent = .{ .space = 4 } } }, buffer.writer()) catch |err| {
            std.log.err("Error Populating Json File: {any}", .{err});
            return false;
        };
        self.usr_file.writeAll(buffer.items) catch |err| {
            std.log.err("Writing to file: {any}", .{err});
            return false;
        };
        buffer.clearAndFree();
        return true;
    }

    fn readConfig() ?std.fs.File {
        var config_dir = std.fs.cwd().openDir("config", .{}) catch ret: {
            std.log.warn("Cannot Open config Directory. Creating One Instead", .{});
            const new_config = std.fs.cwd().makeOpenPath("config", .{}) catch |err| {
                std.log.err("Creating Directory: {any}", .{err});
                return null;
            };

            break :ret new_config;
        };

        const config_file = config_dir.openFile("config.json", .{
            .mode = .read_write,
        }) catch ret: {
            std.log.warn("Cannot Find config.json. Creating One Instead", .{});
            const new_config = config_dir.createFile("config.json", .{
                .read = true,
            }) catch |err| ret2: {
                std.log.err("Cannot Create the json file: {any}", .{err});
                break :ret2 null;
            };
            break :ret new_config;
        };
        config_dir.close();
        return config_file;
    }
};
