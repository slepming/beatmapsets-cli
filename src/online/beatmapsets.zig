const std = @import("std");
const authorization = @import("token.zig");
const http_ext = @import("http.zig");

pub const BeatmapsetSearchQueryOptions = struct {
    query: []const u8 = "",
    /// Currently unsupport
    tags: ?[]Tag = null,
    lang: SortLanguage = SortLanguage.Any,
    categ: SearchCategory = SearchCategory.Any,
    criteria: SortCriteria = SortCriteria.Ranked,
    dir: SortDirection = SortDirection.Ascending,
    mode: SortOsuMode = SortOsuMode.Any,
    genre: SearchGenre = SearchGenre.Any,
};

pub const SearchCategory = enum { Any, HasLeaderboard, Qualified, Ranked, Loved, Pending, Wip, Graveyard };
pub const SortCriteria = enum { Ranked, Rating, Title, Artist, Difficulty, Updated, Plays, Favourites, Relevance, Nominations };
pub const SortDirection = enum { Descending, Ascending };
pub const SortLanguage = enum(u8) {
    Any = 0,
    Unspecified = 1,
    English = 2,
    Chinese = 4,
    French = 7,
    German = 8,
    Italian = 11,
    Japanese = 3,
    Korean = 6,
    Spanish = 10,
    Swedish = 9,
    Russian = 12,
    Polish = 13,
    Instrumental = 5,
    Other = 14,
};
pub const SortOsuMode = enum { Osu, Taiko, Catch, Mania, Any };
pub const SearchGenre = enum(u8) {
    Any = 0,
    Unspecified = 1,
    VideoGame = 2,
    Anime = 3,
    Rock = 4,
    Pop = 5,
    Other = 6,
    Novelty = 7,
    HipHop = 9,
    Electronic = 10,
    Metal = 11,
    Classical = 12,
    Folk = 13,
    Jazz = 14,
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

    pub fn request(
        allocator: std.mem.Allocator,
        client: *std.http.Client,
        tkn: *const authorization.Token,
        search: ?BeatmapsetSearchQueryOptions,
    ) !BeatmapsetSearch {
        const path = "https://osu.ppy.sh/api/v2/beatmapsets/search";
        var modified_url: []const u8 = undefined;
        var buffer: [1024]u8 = undefined;

        const token_slice = std.fmt.bufPrint(&buffer, "{s} {s}", .{ tkn.token_type, tkn.access_token }) catch {
            std.log.err("Authorization token buffer less then token", .{});
            return error.AuthorizationBuffer;
        };

        var token: [1024]u8 = undefined;
        const token_len = token_slice.len;

        @memcpy(token[0..token_len], token_slice);

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
                .value = token[0..token_len],
            },
        };

        var result = std.Io.Writer.Allocating.init(allocator);
        defer result.deinit();

        buffer = undefined;

        if (search) |search_info| {
            std.log.debug("query: {s}", .{search.?.query});
            const queries: []const http_ext.Query = &.{
                .{ .v = @tagName(search_info.categ), .k = "s" },
                .{ .v = @tagName(search_info.criteria), .k = "sort" },
                // .{ .v = std.fmt.form, .k = "l" },
                // .{ .v = search_info.genre, .k = "g" },
                // .{ .v = search_info.mode, .k = "m" },
                // .{ .v = search_info.query, .k = "q" },
            };
            modified_url = try http_ext.append_query(&buffer, path, queries);
        } else {
            modified_url = path;
        }

        std.log.debug("request url {s}", .{modified_url});

        const uri = try std.Uri.parse(modified_url);

        const response = try client.fetch(.{
            .location = .{
                .uri = uri,
            },
            .method = .GET,
            .extra_headers = headers,
            .response_writer = &result.writer,
        });
        const result_slice = result.written();

        if (response.status == .unauthorized) {
            std.log.err("{s}", .{result_slice});
            return error.Unauthorization;
        }

        if (response.status != .ok) {
            std.log.err("{s}", .{result_slice});
            return error.UnhandledResponseStatus;
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
    const allocator = std.testing.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    var client = std.http.Client{
        .allocator = allocator,
        .io = threaded.io(),
    };
    defer client.deinit();

    const tkn = authorization.Token{ .access_token = "", .expires_in = 3, .token_type = "Bearer", .refresh_token = null };

    try std.testing.expectError(error.Unauthorization, BeatmapsetSearch.request(allocator, &client, &tkn, null));
}
