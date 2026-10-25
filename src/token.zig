const httpz = @import("httpz");
const http_ext = @import("http.zig");
const std = @import("std");

var server: ?*httpz.Server(*AuthHandler) = null;
const localhost = "127.0.0.1";
const URI = "https://osu.ppy.sh/";

const AuthHandler = struct {
    code: ?Token = null,
    client_id: u64,
    client_secret: []const u8,
    port: u16,
    allocator: std.mem.Allocator,
    io: std.Io,
};

/// Token structure from osu API v2
pub const Token = struct { token_type: []const u8, expires_in: u32, access_token: []const u8, refresh_token: ?[]const u8 = null };

pub fn auth_client(io: std.Io, allocator: std.mem.Allocator, client_secret: []const u8, client_id: u64, port: u16, scope: []const u8) !Token {
    std.log.info(
        "open in browser: {s}oauth/authorize?client_id={d}&redirect_uri=http://{s}:{d}&response_type=code&scope={s}&state=randomval",
        .{ URI, client_id, localhost, port, scope },
    );

    var auth = AuthHandler{ .allocator = allocator, .client_id = client_id, .port = port, .client_secret = client_secret, .io = io };

    std.log.debug("server starting on {s}:{any}", .{ localhost, port });
    var server_i = try httpz.Server(*AuthHandler).init(io, allocator, .{
        .address = .localhost(port),
    }, &auth);

    defer {
        std.log.debug("server shotdown", .{});
        // clean shutdown, finishes serving any live requests
        server_i.deinit();
    }

    var router = try server_i.router(.{});
    router.get("", listen, .{});

    server = &server_i;

    // blocks
    try server_i.listen();

    if (auth.code) |code| {
        return code;
    } else {
        return error.AuthorizingError;
    }
}

fn listen(h: *AuthHandler, req: *httpz.Request, res: *httpz.Response) !void {
    std.log.debug("server receive message", .{});
    const query = try req.query();
    const code = query.get("code") orelse {
        res.status = 400;
        res.body = "Missing code";
        return error.MissingCode;
    };
    res.status = 200;
    res.header("Content-Type", "text/html; charset=utf-8");
    res.body =
        \\<!DOCTYPE html>
        \\<html>
        \\<style>
        \\html {
        \\    background-color: black;
        \\}
        \\</style>
        \\<head><meta charset="utf-8"><title>OK</title></head>
        \\<body style="font-family: sans-serif; text-align: center; margin-top: 50px;">
        \\  <h2 style="color: white">Authorization success!</h2>
        \\  <p style="color: white">You can close this page!.</p>
        \\</body>
        \\</html>
    ;

    var payload_buffer: [1024]u8 = undefined;

    const payload = try std.fmt.bufPrint(
        &payload_buffer,
        "client_id={d}&client_secret={s}&code={s}&grant_type=authorization_code&redirect_uri=http://{s}:{d}",
        .{ h.client_id, h.client_secret, code, localhost, h.port },
    );

    h.code = try get_token(
        h.allocator,
        h.io,
        payload,
    );

    server.?.stop();
}

pub fn client_credentials_token(
    allocator: std.mem.Allocator,
    io: std.Io,
    client_id: u64,
    client_secret: []const u8,
) !Token {
    var payload_buffer: [1024]u8 = undefined;

    var exchange_code_uri_buffer: [256]u8 = undefined;

    const exchange_code_uri = try std.fmt.bufPrint(&exchange_code_uri_buffer, "{s}oauth/token", .{URI});

    const _client_id = try std.fmt.allocPrint(allocator, "{d}", .{client_id});

    const payload_query = try http_ext.appendQueryToUrl(&payload_buffer, exchange_code_uri, &[_]http_ext.Query{
        .{ .v = _client_id, .k = "client_id" },
        .{ .v = client_secret, .k = "client_secret" },
        .{ .v = "client_credentials", .k = "grant_type" },
        .{ .v = "public", .k = "scope" },
    });

    return get_token(allocator, io, payload_query);
}

fn get_token(allocator: std.mem.Allocator, io: std.Io, exchange_code_uri: []const u8) !Token {
    var allocated_result = std.Io.Writer.Allocating.init(allocator);
    defer allocated_result.deinit();

    var http_client = std.http.Client{ .io = io, .allocator = allocator };

    const headers = &[_]std.http.Header{
        .{
            .name = "Accept",
            .value = "application/json",
        },
        .{
            .name = "Content-Type",
            .value = "application/x-www-form-urlencoded",
        },
    };

    const response = try http_client.fetch(
        .{
            .location = .{
                .uri = try std.Uri.parse(exchange_code_uri),
            },
            .method = .POST,
            .extra_headers = headers,
            .response_writer = &allocated_result.writer,
        },
    );

    const result_slice = allocated_result.written();

    if (response.status != .ok) {
        std.log.err("HTTP status: {d}", .{@backingInt(response.status)});
        std.log.err("{s}", .{result_slice});
    }

    const parsed = try std.json.parseFromSlice(
        Token,
        allocator,
        result_slice,
        .{
            .ignore_unknown_fields = true,
        },
    );
    defer parsed.deinit();

    return parsed.value;
}
