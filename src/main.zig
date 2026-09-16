const std = @import("std");
const api = @import("beatmapsets_cli");
const args = @import("args");
const Io = std.Io;

const DESCRIPTION: []const u8 = "Simplest osu! api v2 wrapper with cli";
const NAME: []const u8 = "beatmapsets-cli";
const VERSION: []const u8 = "0.0.1";
const PORT: u32 = 3000;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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

    try parser.addOption("search-beatmapsets", .{
        .short = 's',
        .help = "Search terms",
    });

    // Parse command-line arguments from the process init context
    var result = try parser.parseProcess(init);
    defer result.deinit();

    //const verbose = result.getBool("verbose") orelse false;
    const search_beatmapsets = result.getString("search-beatmapsets");
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
    }
}

fn search_beatmapsets_f(io: std.Io, allocator: std.mem.Allocator, q: []const u8, client_secret: []const u8, client_id: u64, authorization_type: bool) !void {
    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();
    var token: api.token.Token = try authorization(io, allocator, client_secret, client_id, authorization_type);
    const beatmapset_s = try api.beatmapsets.BeatmapsetSearch.request(
        allocator,
        &http_client,
        &token,
        .{ .query = q },
    );

    const beatmapsets = beatmapset_s.beatmapsets;

    for (beatmapsets) |beatmap| {
        std.log.debug("{s}", .{beatmap.title});
    }
}

fn authorization(io: std.Io, allocator: std.mem.Allocator, client_secret: []const u8, client_id: u64, authorization_type: bool) !api.token.Token {
    if (authorization_type) {
        return api.token.auth_client(io, allocator, client_secret, client_id, PORT, "public");
    }

    return api.token.client_credentials_token(allocator, io, client_id, client_secret);
}
