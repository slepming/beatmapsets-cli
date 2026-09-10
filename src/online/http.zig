//! Http extensions

const std = @import("std");
const expect = std.testing.expect;

pub const Query = struct { k: []const u8, v: []const u8 };

/// Append query to base url.
pub fn append_query(buf: []u8, url: []const u8, kv: []const Query) ![]const u8 {
    var cursor: usize = 0;

    if (buf.len < url.len) return error.NoSpaceLeft;
    @memcpy(buf[cursor..], url);
    cursor += url.len;

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

test "http append query" {
    var buffer: [1024]u8 = undefined;

    const paths: [][]const u8 = [][]const u8{
        .{"https://example.com/api/"},
        .{"http://example.com/api"},
        .{"http:/example.com/api"},
        .{"http::/example.com/api"},
        .{"http//example.com/api"},
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
        expect(try append_query(&buffer, path, queries) == result);
    }
}
