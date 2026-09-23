const std = @import("std");
const auth = @import("token.zig");
const str_ext = @import("str.zig");
const http_ext = @import("http.zig");

/// User options must contains either username or id.
/// If UserOptions contains username request endpoint will have @ before nickname. (See [Docs](https://osu.ppy.sh/docs/index.html#get-user))
///
/// # Note
///
/// If both values equals null get_user() function or similar priority is given to id
pub const UserOptions = struct { username: ?[]const u8 = null, id: ?u64 = null, mode: Rulesets = .Osu };

pub const Rulesets = enum { Osu, Taiko, Mania, Catch };

pub const Kudosu = struct {
    total: u32,
    available: u32,
};

pub const Country = struct {
    code: []const u8,
    name: []const u8,
};

pub const Cover = struct {
    custom_url: ?[]const u8 = null,
    url: ?[]const u8 = null,
    id: ?[]const u8 = null,
};

pub const Badge = struct {
    awarded_at: []const u8,
    description: []const u8,
    @"image@2x_url": []const u8,
    image_url: []const u8,
    url: []const u8,
};

pub const Group = struct {
    id: u32,
    identifier: []const u8,
    name: []const u8,
    short_name: []const u8,
    description: []const u8,
    colour: []const u8,
    playmodes: ?[][]const u8 = null,
};

pub const DateCount = struct {
    start_date: []const u8,
    count: u32,
};

pub const Page = struct {
    html: []const u8,
    raw: []const u8,
};

pub const Level = struct {
    current: u32,
    progress: f32,
};

pub const GradeCounts = struct {
    ss: u32,
    ssh: u32,
    s: u32,
    sh: u32,
    a: u32,
};

pub const Rank = struct {
    global: ?u32 = null,
    country: u32,
};

pub const DailyChallengeUserStats = struct {
    daily_streak_best: u32,
    daily_streak_current: u32,
    last_update: []const u8,
    last_weekly_streak: []const u8,
    playcount: u32,
    top_10p_placements: u32,
    top_50p_placements: u32,
    user_id: u64,
    weekly_streak_best: u32,
    weekly_streak_current: u32,
};

pub const RankHighest = struct {
    rank: u32,
    updated_at: []const u8,
};

pub const RankHistory = struct {
    mode: []const u8,
    data: []u32,
};

pub const AccountHistory = struct {
    description: ?[]const u8 = null,
    id: u32,
    length: u32,
    permanent: bool,
    timestamp: []const u8,
    type: []const u8,
};

pub const ProfileBanner = struct {
    id: u32,
    tournament_id: u32,
    image: ?[]const u8 = null,
    @"image@2x": ?[]const u8 = null,
};

pub const UserAchievement = struct {
    achieved_at: []const u8,
    achievement_id: u32,
};

pub const Statistics = struct {
    count_100: u32,
    count_300: u32,
    count_50: u32,
    count_miss: u32,
    level: Level,
    global_rank: ?u32 = null,
    global_rank_percent: ?f32 = null,
    global_rank_exp: ?u32 = null,
    pp: f32,
    pp_exp: ?u32 = null,
    ranked_score: u64,
    hit_accuracy: f32,
    accuracy: f32,
    play_count: u32,
    play_time: ?u32 = null,
    total_score: u64,
    total_hits: u64,
    maximum_combo: u32,
    replays_watched_by_others: u32,
    is_ranked: bool,
    grade_counts: GradeCounts,
    country_rank: ?u32 = null,
    rank: Rank,
    rank_change_since_30_days: ?i32 = null,
};

pub const User = struct {
    id: u64,
    username: []const u8,
    profile_colour: ?[]const u8 = null,
    avatar_url: []const u8,
    country_code: []const u8,
    default_group: ?[]const u8 = null,
    is_active: bool,
    is_bot: bool,
    is_deleted: bool,
    is_online: bool,
    is_supporter: bool,
    last_visit: ?[]const u8 = null,
    pm_friends_only: bool,

    cover_url: ?[]const u8 = null,
    discord: ?[]const u8 = null,
    has_supported: bool,
    interests: ?[]const u8 = null,
    join_date: []const u8,
    location: ?[]const u8 = null,
    max_blocks: u32,
    max_friends: u32,
    occupation: ?[]const u8 = null,
    playmode: []const u8,
    playstyle: [][]const u8,
    post_count: u32,
    profile_hue: ?u32 = null,
    profile_order: [][]const u8,
    title: ?[]const u8 = null,
    title_url: ?[]const u8 = null,
    twitter: ?[]const u8 = null,
    website: ?[]const u8 = null,

    country: ?Country = null,
    cover: ?Cover = null,
    kudosu: ?Kudosu = null,
    page: ?Page = null,
    statistics: ?Statistics = null,
    rank_highest: ?RankHighest = null,
    daily_challenge_user_stats: ?DailyChallengeUserStats = null,

    account_history: ?[]std.json.Value = null,
    active_tournament_banner: ?ProfileBanner = null,
    active_tournament_banners: ?[]std.json.Value = null,
    badges: ?[]Badge = null,
    groups: ?[]Group = null,
    monthly_playcounts: ?[]DateCount = null,
    replays_watched_counts: ?[]DateCount = null,
    user_achievements: ?[]UserAchievement = null,
    rank_history: ?RankHistory = null,
    rankHistory: ?RankHistory = null, // osu! иногда присылает этот camelCase дубликат

    matchmaking_stats: ?[]std.json.Value = null,
    current_season_stats: ?[]const u8 = null,
    current_user_attributes: ?[]const u8 = null,
    statistics_rulesets: ?std.json.Value = null,
    user_preferences: ?std.json.Value = null,

    is_restricted: ?bool = null,
    beatmap_playcounts_count: u32,
    comments_count: u32,
    favourite_beatmapset_count: u32,
    follower_count: u32,
    graveyard_beatmapset_count: u32,
    guest_beatmapset_count: u32,
    loved_beatmapset_count: u32,
    mapping_follower_count: u32,
    nominated_beatmapset_count: u32,
    pending_beatmapset_count: u32,
    previous_usernames: ?[][]const u8 = null,
    ranked_beatmapset_count: u32,
    ranked_and_approved_beatmapset_count: u32,
    unranked_beatmapset_count: u32,
    scores_best_count: u32,
    scores_first_count: u32,
    scores_pinned_count: u32,
    scores_recent_count: u32,
    support_level: u32,
    team: ?[]const u8 = null,
    follow_user_mapping: ?[]u32 = null,
    friends: ?[]std.json.Value = null,
    unread_pm_count: ?u32 = null,
    session_verified: ?bool = null,

    pub fn get_user(allocator: std.mem.Allocator, client: *std.http.Client, tkn: *const auth.Token, user: UserOptions) !User {
        const path = "https://osu.ppy.sh/api/v2/users/";
        var modified_url: []const u8 = undefined;
        var buffer: [1024]u8 = undefined;
        var number_buffer: [128]u8 = undefined;
        var mode_buffer: [16]u8 = undefined;

        const token_slice = std.fmt.bufPrint(&buffer, "{s} {s}", .{ tkn.token_type, tkn.access_token }) catch |err| {
            std.log.err("Authorization token buffer less then token", .{});
            return err;
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

        if (user.id) |id| {
            modified_url = try std.fmt.bufPrint(&buffer, "{s}{s}/{s}", .{
                path,
                try str_ext.from(u64, &number_buffer, id),
                std.ascii.lowerString(&mode_buffer, @tagName(user.mode)),
            });
        } else if (user.username) |username| {
            modified_url = try std.fmt.bufPrint(&buffer, "{s}@{s}/{s}", .{
                path,
                username,
                std.ascii.lowerString(&mode_buffer, @tagName(user.mode)),
            });
        } else return error.usernameAndIdEqualsNull;

        const value = try http_ext.fetch(User, client, allocator, modified_url, headers, .GET);

        return value.value;
    }
};

test "get_user_by_username" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var env = try std.testing.environ.createMap(allocator);
    defer env.deinit();

    const tkn = env.get("OSU_API_TOKEN");

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();

    if (tkn) |token| {
        const structed_token = auth.Token{
            .access_token = token,
            .token_type = "Bearer",
            .expires_in = 0,
            .refresh_token = null,
        };

        const user = try User.get_user(allocator, &http_client, &structed_token, .{ .username = "slepming" });

        try std.testing.expectEqual(29155149, user.id);
    } else {
        std.log.err("OSU_API_TOKEN variable is empty. For tests you need get token from osu api", .{});
        return error.TokenUnavailable;
    }
}

test "get_user_by_id" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var env = try std.testing.environ.createMap(allocator);
    defer env.deinit();

    const tkn = env.get("OSU_API_TOKEN");

    var http_client = std.http.Client{ .allocator = allocator, .io = io };
    defer http_client.deinit();

    if (tkn) |token| {
        const structed_token = auth.Token{
            .access_token = token,
            .token_type = "Bearer",
            .expires_in = 0,
            .refresh_token = null,
        };

        const user = try User.get_user(allocator, &http_client, &structed_token, .{ .id = 29155149 });
        std.debug.print("DEBUG: Username ptr: {*}, len: {d}\n", .{ user.username.ptr, user.username.len });
        std.debug.print(
            "ptr = 0x{x}, len = {}\n",
            .{ @intFromPtr(user.username.ptr), user.username.len },
        );

        try std.testing.expectEqualStrings("slepming", user.username); // Segmentation fault on user.username when retreiving the index value
    } else {
        std.log.err("OSU_API_TOKEN variable is empty. For tests you need get token from osu api", .{});
        return error.TokenUnavailable;
    }
}
