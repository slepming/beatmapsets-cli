//! Http extensions

const std = @import("std");
const testing = std.testing;

pub const URL_MAX_LENGTH = 1024;

pub const Query = struct { k: []const u8, v: []const u8 };

/// Append query to base url with url size value.
///
/// Result live while buffer live
pub fn append_query_raw(buf: []u8, url: []const u8, kv: []const Query, val: usize) ![]const u8 {
    var cursor: usize = 0;

    if (buf.len < url.len) return error.NoSpaceLeft;

    @memcpy(buf[cursor..val], url[0..val]);
    cursor += val;

    for (kv, 0..) |q, i| {
        const sep: u8 = if (i == 0) 0x3F else 0x26;
        const query_size = 1 + q.k.len + 1 + q.v.len;

        if (buf.len < cursor + query_size) return error.NoSpaceLeft;

        buf[cursor] = sep;
        cursor += 1;

        @memcpy(buf[cursor .. cursor + q.k.len], q.k);
        cursor += q.k.len;

        buf[cursor] = 0x3D;
        cursor += 1;

        @memcpy(buf[cursor .. cursor + q.v.len], q.v);
        cursor += q.v.len;
    }

    return buf[0..cursor];
}

pub fn append_query_http(buf: []u8, url: []const u8, kv: []const Query) ![]const u8 {
    return append_query_raw(buf, url, kv, url.len);
}

pub fn append_query(buf: []u8, url_raw: []const u8, kv: []const Query) ![]const u8 {
    var protocol = std.mem.splitAny(u8, url_raw, ":");
    var url: [URL_MAX_LENGTH]u8 = undefined;

    var url_size = url_raw.len;
    if (url_raw[url_raw.len - 1] == 0x3A) {
        url_size = url_raw.len - 2;
        @memcpy(url[0..url_size], url_raw[0..url_size]);
    } else @memcpy(url[0..url_raw.len], url_raw);

    if (!std.mem.eql(u8, protocol.first(), "https")) {
        std.log.debug("You are not using the https protocol. If it's intentional use instead append_query_raw()", .{});
        if (std.mem.replace(u8, &url, protocol.first(), "https", &url) == 0) {
            return error.ReplaceMemoryError;
        }
    }

    std.log.debug("Current url {s}", .{url});
    return append_query_raw(
        buf,
        &url,
        kv,
        url_size,
    );
}

test "http append query" {
    var buffer: [1024]u8 = undefined;

    const paths: [5][]const u8 = .{
        "https://example.com/api/",
        "http://example.com/api",
        "http:/example.com/api",
        "http::/example.com/api",
        "http//example.com/api",
    };

    const result = "https://example.com/api?work=true&test=success";

    const queries: []const Query = &.{
        .{
            .k = "work",
            .v = "true",
        },
        .{
            .k = "test",
            .v = "success",
        },
    };

    for (paths) |path| {
        const extended_url = try append_query(&buffer, path, queries);
        try testing.expectEqualStrings(result, extended_url);
    }
}
