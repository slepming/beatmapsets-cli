pub const api = @import("beatmapsets_cli");
const std = @import("std");
const zio = @import("zio");
const args = @import("args");
const config = @import("config");
const Io = std.Io;

pub const DESCRIPTION: []const u8 = "Simplest osu! api v2 wrapper with cli";
pub const NAME: []const u8 = "beatmapsets-cli";
pub const VERSION: []const u8 = "0.0.3";
pub const PORT: u32 = 3000;

pub fn main(init: std.process.Init) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var zr = try zio.Runtime.init(allocator, .{});
    defer zr.deinit();

    const io = zr.io();

    // Create argument parser
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = NAME,
        .version = VERSION,
        .description = DESCRIPTION,
    });
    defer parser.deinit();

    // Add arguments
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    try parser.addFlag("client", .{
        .help = "Enable client authorization",
    });

    try parser.addFlag("tui", .{
        .help = "Enable tui client",
    });

    try parser.addOption("search-beatmapsets", .{
        .short = 's',
        .help = "Search beatmapsets",
    });

    try parser.addOption("user-by-id", .{ .help = "get user by id", .value_type = .int });

    try parser.addOption("user-by-username", .{ .help = "get user by username", .value_type = .string });

    // Parse command-line arguments from the process init context
    var result = try parser.parseProcess(init);
    defer result.deinit();

    //const verbose = result.getBool("verbose") orelse false;
    const tui_enabled = result.getBool("tui") orelse false;
    if (!tui_enabled) {
        const search_beatmapsets = result.getString("search-beatmapsets");
        const user_by_id = result.getInt("user-by-id");
        const user_authorization = result.getBool("client") orelse false;

        const client_id_raw = init.environ_map.get("OSU_API_CLIENT_ID") orelse {
            std.log.err("Environment variable 'OSU_API_CLIENT_ID' is null", .{});
            return error.AuthorizationError;
        };

        const client_id = try std.fmt.parseInt(u64, client_id_raw, 10);

        const client_secret = init.environ_map.get("OSU_API_CLIENT_SECRET") orelse {
            std.log.err("Environment variable 'OSU_API_CLIENT_SECRET' is null", .{});
            return error.AuthorizationError;
        };

        if (search_beatmapsets) |q| {
            try search_beatmapsets_f(io, allocator, q, client_secret, client_id, user_authorization);
        } else if (user_by_id) |user| {
            try get_user(io, allocator, user, client_secret, client_id);
        }
    } else {
        if (config.disable_tui) {
            const zz = @import("zigzag");
            const tui = @import("tui.zig");
            var program = zz.Program(tui.Model).initWithOptions(allocator, io, init.environ_map, .{ .fps = 29, .title = NAME });
            defer program.deinit();

            try program.run();
        } else {
            return error.TUINotInBuild;
        }
    }
}

fn search_beatmapsets_f(io: std.Io, allocator: std.mem.Allocator, q: ?[]const u8, client_secret: []const u8, client_id: u64, authorization_type: bool) !void {
    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();
    var token: api.token.Token = try authorization(io, allocator, client_secret, client_id, authorization_type);
    const beatmapset_s = try api.beatmapsets.BeatmapsetSearch.request(
        allocator,
        &http_client,
        &writer,
        &token,
        .{ .query = q },
    );

    const _beatmapsets = beatmapset_s.value.beatmapsets;

    if (_beatmapsets) |beatmapsets| {
        for (beatmapsets) |beatmap| {
            std.log.debug("{s}", .{beatmap.title});
        }
    }
}

fn get_user(io: std.Io, allocator: std.mem.Allocator, id: i64, client_secret: []const u8, client_id: u64) !void {
    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();
    var token: api.token.Token = try authorization(io, allocator, client_secret, client_id, false);
    const user = try api.user.User.get_user(
        allocator,
        &http_client,
        &writer,
        &token,
        .{ .id = @intCast(id) },
    );

    std.debug.print("{s}", .{user.value.username});
}

pub fn authorization(io: std.Io, allocator: std.mem.Allocator, client_secret: []const u8, client_id: u64, authorization_type: bool) !api.token.Token {
    if (authorization_type) {
        return api.token.auth_client(io, allocator, client_secret, client_id, PORT, "public");
    }

    return api.token.client_credentials_token(allocator, io, client_id, client_secret);
}
