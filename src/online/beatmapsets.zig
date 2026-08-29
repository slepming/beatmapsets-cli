const std = @import("std");
const token = @import("token.zig");

pub const Search = struct {
    text: [][]const u8,
    /// Currently unsupport
    tags: []Tag,
};

/// Beatmapsets tags
pub const Tag = enum { Stream };

pub const Covers = struct {
    cover: []const u8,
    @"cover@2x": []const u8,
    card: []const u8,
    @"card@2x": []const u8,
    list: []const u8,
    @"list@2x": []const u8,
    slimcover: []const u8,
    @"slimcover@2x": []const u8,
};

pub const Beatmap = struct {
    id: u64,
    beatmapset_id: u64,
    difficulty_rating: f64,
    mode: []const u8,
    status: []const u8,
    total_length: u32,
    user_id: u64,
    version: []const u8,
    accuracy: f32,
    ar: f32,
    bpm: ?f64 = null,
    convert: bool = false,
    count_circles: u32,
    count_sliders: u32,
    count_spinners: u32,
    cs: f32,
    deleted_at: ?[]const u8 = null,
    drain: f32,
    hit_length: u32,
    is_scoreable: bool,
    last_updated: []const u8,
    mode_int: u8,
    passcount: u64 = 0,
    playcount: u64 = 0,
    ranked: i8,
    url: []const u8,
    checksum: ?[]const u8 = null,
    max_combo: ?u32 = null,
};

pub const Beatmapset = struct {
    id: u64,
    artist: []const u8,
    artist_unicode: ?[]const u8 = null,
    title: []const u8,
    title_unicode: ?[]const u8 = null,
    creator: []const u8,
    source: []const u8 = "",
    status: []const u8,
    covers: Covers,
    anime_cover: bool = false,
    nsfw: bool = false,
    spotlight: bool = false,
    storyboard: bool = false,
    video: bool = false,
    preview_url: ?[]const u8 = null,
    bpm: f64,
    can_be_hyped: bool = false,
    is_scoreable: bool = false,
    favourite_count: u64 = 0,
    play_count: u64 = 0,
    rating: f64 = 0.0,
    hype: ?u64 = null,
    last_updated: []const u8,
    submitted_date: ?[]const u8 = null,
    ranked_date: ?[]const u8 = null,
    genre_id: ?u64 = null,
    language_id: ?u64 = null,
    offset: ?i64 = null,
    tags: []const u8 = "",
    pack_tags: ?[]const []const u8 = null,
    track_id: ?u32 = null,
    beatmaps: ?[]const Beatmap = null,
};

pub const BeatmapsetSearch = struct {
    beatmapsets: []Beatmapset,
    total: u64,
    cursor: ?std.json.Value = null,

    pub fn request(client: *std.http.Client, tkn: *const token.Token, allocator: std.mem.Allocator) !BeatmapsetSearch {
        const path = "https://osu.ppy.sh/api/v2/beatmapsets/search";
        std.log.debug("request {s} sent", .{path});
        var authorization_token: [1024]u8 = undefined;

        const token_header = std.fmt.bufPrint(&authorization_token, "{s} {s}", .{ tkn.token_type, tkn.access_token }) catch {
            std.log.err("Authorization token buffer less then token", .{});
            return error.AuthorizationBuffer;
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
                .value = token_header,
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
        const result_slice = result.written();

        if (response.status == .unauthorized) {
            return error.Unauthorization;
        }

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
