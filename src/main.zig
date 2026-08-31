const std = @import("std");
const api = @import("osu_api");
const args = @import("args");
const Io = std.Io;

const DESCRIPTION: []const u8 = "Simplest cli osu! api v2 wrapper with cli";
const NAME: []const u8 = "beatmapsets-cli";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create argument parser
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = NAME,
        .version = "1.0.0",
        .description = DESCRIPTION,
    });
    defer parser.deinit();

    // Add arguments
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    try parser.addFlag("client", .{
        .short = 'c',
        .help = "Enable user authorization",
    });

    try parser.addOption("search-beatmapsets", .{
        .short = 's',
        .help = "Search terms",
    });

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();

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

    if (search_beatmapsets) |_| {
        var token: api.token.Token = undefined;
        if (user_authorization) {
            token = try api.token.auth_client(io, allocator, client_secret, client_id, 3000, "public");
        } else token = try api.token.client_credentials_token(allocator, io, client_id, client_secret);
        const beatmapset_s = try api.beatmapsets.BeatmapsetSearch.request(allocator, &http_client, &token, null);
        const beatmapsets = beatmapset_s.beatmapsets;

        for (beatmapsets) |beatmap| {
            std.log.debug("{s}", .{beatmap.title});
        }
    }
}
