//! Http extensions

const std = @import("std");

const testing = std.testing;

pub const URL_MAX_LENGTH = 1024;

pub const HttpStatusError = error{ UnhandledResponseStatus, Unauthorization };

pub const Query = struct { k: []const u8, v: []const u8 };

/// Append query to base url with url size value.
///
/// Result live while buffer live
pub fn append_query_raw(buf: []u8, url: []const u8, kv: []const Query, val: usize) std.fmt.BufPrintError![]const u8 {
    var cursor: usize = 0;

    if (buf.len < url.len) return std.fmt.BufPrintError.NoSpaceLeft;

    @memcpy(buf[cursor..val], url[0..val]);
    cursor += val;

    for (kv, 0..) |q, i| {
        const sep: u8 = if (i == 0) 0x3F else 0x26;
        const query_size = 1 + q.k.len + 1 + q.v.len;

        if (buf.len < cursor + query_size) return std.fmt.BufPrintError.NoSpaceLeft;

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

pub fn append_query_http(buf: []u8, url: []const u8, kv: []const Query) std.fmt.BufPrintError![]const u8 {
    return append_query_raw(buf, url, kv, url.len);
}

pub fn append_query(buf: []u8, url_raw: []const u8, kv: []const Query) std.fmt.BufPrintError![]const u8 {
    if (buf.len < url_raw.len) return std.fmt.BufPrintError.NoSpaceLeft;
    var url: [URL_MAX_LENGTH]u8 = undefined;

    var url_size = url_raw.len;
    if (url_raw[url_raw.len - 1] == 0x2F) {
        url_size = url_raw.len - 1;
        @memcpy(url[0..url_size], url_raw[0..url_size]);
    } else @memcpy(url[0..url_raw.len], url_raw);

    return append_query_raw(
        buf,
        &url,
        kv,
        url_size,
    );
}

pub fn fetch(
    comptime T: type,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
    url: []const u8,
    headers: []const std.http.Header,
    method: std.http.Method,
) !std.json.Parsed(T) {
    const uri = try std.Uri.parse(url);

    var result = std.Io.Writer.Allocating.init(allocator);
    defer result.deinit();

    const response = try client.fetch(.{
        .location = .{
            .uri = uri,
        },
        .method = method,
        .extra_headers = headers,
        .response_writer = &result.writer,
    });

    const result_slice = result.written();

    if (response.status == .unauthorized) {
        return HttpStatusError.Unauthorization;
    }

    if (response.status != .ok) {
        std.log.err("{s}", .{result_slice});
        return HttpStatusError.UnhandledResponseStatus;
    }

    const parsed = try std.json.parseFromSlice(
        T,
        allocator,
        result_slice,
        .{
            .ignore_unknown_fields = true,
        },
    );
    defer parsed.deinit();

    return parsed;
}

test "http_append_query" {
    var buffer: [1024]u8 = undefined;

    const paths: [2][]const u8 = .{
        "https://example.com/api/",
        "https://example.com/api",
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
