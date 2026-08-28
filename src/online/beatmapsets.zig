const std = @import("std");
const token = @import("token.zig");

pub const Search = struct {
    text: [][]const u8,
    /// Currently unsupport
    tags: []Tag,
};

/// Beatmapsets tags
pub const Tag = enum { Stream };

pub const Beatmapset = struct {
    anime_cover: bool,
    artist: []u8,
    artist_unicode: []u8,
    covers: Covers,
    creator: []u8,
    favourite_count: u64,
    genre_id: u64,
    hype: u64,
    id: u64,
    language_id: u64,
    nsfw: bool,
    offset: u64,
    play_count: u64,
    preview_url: []u8,
    source: []u8,
    spotlight: bool,
    title: []u8,
    title_unicode: []u8,
    bpm: f64,
    can_be_hyped: bool,
};

pub const Beatmap = struct {
    id: u64,
};

pub const Covers = struct {
    // cover: []u8,
    // @"cover@2x": []u8,
    // card: []u8,
    // @"card@2x": []u8,
    // list: []u8,
    // @"list@2x": []u8,
    // slimcover: []u8,
    // @"slimcover@2x": []u8,
};

pub const BeatmapsetSearch = struct {
    beatmapsets: []Beatmapset,
    total: u64,
    cursor_string: []u8,

    pub fn request(client: *std.http.Client, tkn: *const token.Token, allocator: std.mem.Allocator) !BeatmapsetSearch {
        const path = "https://osu.ppy.sh/api/v2/beatmapsets/search";
        std.log.debug("request {s} sent", .{path});
        var authorization_token: [512]u8 = undefined;

        _ = std.fmt.bufPrint(&authorization_token, "{s} {s}", .{ tkn.token_type, tkn.access_token }) catch {
            std.log.err("Authorization token buffer less then token", .{});
        };

        const headers = &[_]std.http.Header{
            .{
                .name = "Accept",
                .value = "application/json",
            },
            .{
                .name = "x-api-version",
                .value = "2",
            },
            .{
                .name = "Authorization",
                .value = &authorization_token,
            },
        };

        var result = std.Io.Writer.Allocating.init(allocator);
        defer result.deinit();

        const response = try client.fetch(.{
            .location = .{
                .uri = try std.Uri.parse(path),
            },
            .method = .GET,
            .extra_headers = headers,
            .response_writer = &result.writer,
        });

        if (response.status == .unauthorized) {
            return error.Unauthorization;
        }

        const result_slice = result.written();
        std.log.debug("{s}", .{result_slice});
        const parsed = try std.json.parseFromSlice(
            BeatmapsetSearch,
            allocator,
            result_slice,
            .{
                .ignore_unknown_fields = true,
            },
        );
        defer parsed.deinit();

        return parsed.value;
    }
};

test "Beatmapset unauthorized requests" {
    const allocator = std.heap.page_allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    var client = std.http.Client{
        .allocator = allocator,
        .io = threaded.io(),
    };
    defer client.deinit();
    try std.testing.expectError(error.Unauthorized, BeatmapsetSearch.request(&client, "", allocator));
}
