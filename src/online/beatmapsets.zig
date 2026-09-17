const std = @import("std");
const authorization = @import("token.zig");
const http_ext = @import("http.zig");
const str = @import("../str.zig");

pub const SearchBeatmapsetsError = std.fmt.BufPrintError || http_ext.HttpStatusError || std.http.Client.FetchError;

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

/// See [caterogy](https://osu.ppy.sh/wiki/en/Beatmap/Category)
pub const SearchCategory = enum { Any, HasLeaderboard, Qualified, Ranked, Loved, Pending, Wip, Graveyard };
pub const SortCriteria = enum { Ranked, Rating, Title, Artist, Difficulty, Updated, Plays, Favourites, Relevance, Nominations };
pub const SortDirection = enum { Descending, Ascending };
/// See [Genre and Languages](https://osu.ppy.sh/wiki/en/Beatmap/Genre_and_language)
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
/// See [Modes](https://osu.ppy.sh/wiki/en/Game_mode)
pub const SortOsuMode = enum { Osu, Taiko, Catch, Mania, Any };
/// See [Genre and Languages](https://osu.ppy.sh/wiki/en/Beatmap/Genre_and_language)
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
///
/// See also [Song setup](https://osu.ppy.sh/wiki/en/Client/Beatmap_editor/Song_setup)
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

/// See wiki [beatmap](https://osu.ppy.sh/wiki/en/Beatmap)
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
    /// See [`SortOsuMode`]
    mode_int: u8,
    passcount: u64 = 0,
    playcount: u64 = 0,
    ranked: i8,
    url: []const u8,
    checksum: ?[]const u8 = null,
    max_combo: ?u32 = null,

    /// Returns beatmap by beatmap(not beatmapset id) id
    ///
    /// See also [Beatmap](https://osu.ppy.sh/wiki/en/Beatmap)
    pub fn get_beatmap(allocator: std.mem.Allocator, client: *std.http.Client, tkn: *const authorization.Token, id: u32) !Beatmap {
        const path = "https://osu.ppy.sh/api/v2/beatmaps/";
        var modified_url: []const u8 = undefined;
        var buffer: [1024]u8 = undefined;

        const token_slice = std.fmt.bufPrint(&buffer, "{s} {s}", .{ tkn.token_type, tkn.access_token }) catch {
            std.log.err("Authorization token buffer less then token", .{});
            return SearchBeatmapsetsError.NoSpaceLeft;
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
                .name = "Content-Type",
                .value = "application/json",
            },
            .{
                .name = "Authorization",
                .value = token[0..token_len],
            },
        };

        buffer = undefined;

        modified_url = try std.fmt.bufPrint(&buffer, "{s}{}", .{ path, id });

        const value = try http_ext.fetch_with_json(Beatmap, client, allocator, modified_url, headers);
        return value.value;
    }
};

/// See wiki [beatmap](https://osu.ppy.sh/wiki/en/Beatmap)
pub const Beatmapset = struct {
    id: u64,
    /// Music artist
    artist: []const u8,
    artist_unicode: ?[]const u8 = null,
    title: []const u8,
    title_unicode: ?[]const u8 = null,
    /// Map creator
    creator: []const u8,
    source: []const u8 = "",
    status: []const u8,
    /// Beatmapset avatar, background img from osu.ppy.sh/beatmasets/id
    covers: Covers,
    /// If beatmapset will has an anime cover will be true
    anime_cover: bool = false,
    nsfw: bool = false,
    spotlight: bool = false,
    /// Does beatmapset have a storyboard?
    storyboard: bool = false,
    /// Does beatmapset have a video background?
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
    /// See [`SearchGenre`]
    genre_id: ?u64 = null,
    /// See [`SortLanguage`]
    language_id: ?u64 = null,
    offset: ?i64 = null,
    tags: []const u8 = "",
    pack_tags: ?[]const []const u8 = null,
    track_id: ?u32 = null,
    /// Beatmapset contains beatmap (with difficulties like 3 star beatmap with title "expert")
    ///
    /// See osu wiki [beatmap](https://osu.ppy.sh/wiki/en/Beatmap)
    beatmaps: ?[]const Beatmap = null,
};

pub const Search = struct { sort: []const u8 };
pub const Cursor = struct { approved_date: i64, id: i64 };

pub const BeatmapsetSearch = struct {
    /// Beatmapsets array from search
    beatmapsets: []Beatmapset,
    total: u64,
    @"error": ?[]const u8 = null,
    /// Sort parameter
    search: Search,
    /// Recommended for user difficulty
    recommended_difficulty: ?[]const u8 = null,
    /// Cursor to next to new beatmapets page
    cursor_string: []const u8,
    cursor: Cursor,

    /// Returns structure by search options
    ///
    /// See also [SearchBeatmapsets](https://osu.ppy.sh/docs/index.html#search-beatmapset)
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
            return SearchBeatmapsetsError.NoSpaceLeft;
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

        buffer = undefined;

        var language: [3]u8 = undefined;
        var mode: [3]u8 = undefined;
        var genre: [3]u8 = undefined;

        if (search) |search_info| {
            std.log.debug("query: {s}", .{search.?.query});
            const queries: []const http_ext.Query = &.{
                .{ .v = @tagName(search_info.categ), .k = "s" },
                .{ .v = @tagName(search_info.criteria), .k = "sort" },
                .{ .v = try str.from_u8(&language, @intFromEnum(search_info.lang)), .k = "l" },
                .{ .v = try str.from_u8(&genre, @intFromEnum(search_info.genre)), .k = "g" },
                .{ .v = try str.from_u8(&mode, @intFromEnum(search_info.mode)), .k = "m" },
                .{ .v = search_info.query, .k = "q" },
            };
            modified_url = try http_ext.append_query(&buffer, path, queries);
        } else {
            modified_url = path;
        }

        std.log.debug("request url {s}", .{modified_url});

        const value = try http_ext.fetch_with_json(BeatmapsetSearch, client, allocator, modified_url, headers);
        return value.value;
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

    try std.testing.expectError(SearchBeatmapsetsError.Unauthorization, BeatmapsetSearch.request(allocator, &client, &tkn, null));
}

test "Beatmapset authorized request" {
    const allocator = std.testing.allocator;

    const io = std.testing.io;
    var env = try std.testing.environ.createMap(allocator);
    defer env.deinit();

    const tkn = env.get("OSU_API_TOKEN");

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();

    if (tkn) |token| {
        const structed_token = authorization.Token{
            .access_token = token,
            .token_type = "Bearer",
            .expires_in = 0,
            .refresh_token = null,
        };

        const beatmapsets = try BeatmapsetSearch.request(
            allocator,
            &http_client,
            &structed_token,
            null,
        );

        try std.testing.expectEqual(50, beatmapsets.beatmapsets.len);
    } else {
        std.log.err("OSU_API_TOKEN variable is empty. For tests you need get token from osu api", .{});
        return error.TokenUnavailable;
    }
}

test "Receive beatmap by id" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var env = try std.testing.environ.createMap(allocator);
    defer env.deinit();

    const tkn = env.get("OSU_API_TOKEN");

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();

    if (tkn) |token| {
        const structed_token = authorization.Token{
            .access_token = token,
            .token_type = "Bearer",
            .expires_in = 0,
            .refresh_token = null,
        };

        const beatmap = try Beatmap.get_beatmap(allocator, &http_client, &structed_token, 33502);

        try std.testing.expectEqual(8023, beatmap.beatmapset_id);
    } else {
        std.log.err("OSU_API_TOKEN variable is empty. For tests you need get token from osu api", .{});
        return error.TokenUnavailable;
    }
}
