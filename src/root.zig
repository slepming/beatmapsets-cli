const std = @import("std");
const httpz = @import("httpz");
pub const beatmapsets = @import("online/beatmapsets.zig");

var server: ?*httpz.Server(*AuthHandler) = null;

const AuthHandler = struct {
    code: ?[]const u8 = null,
    allocator: std.mem.Allocator,
};

pub fn auth_client(io: std.Io, allocator: std.mem.Allocator, client_id: u64, port: u16, scope: []const u8) ![]const u8 {
    std.log.debug(
        "https://osu.ppy.sh/oauth/authorize?client_id={d}&redirect_uri=http://127.0.0.1:{d}&response_type=code&scope={s}&state=randomval",
        .{ client_id, port, scope },
    );

    var auth = AuthHandler{ .allocator = allocator };
    var server_i = try httpz.Server(*AuthHandler).init(io, allocator, .{
        .address = .localhost(3000),
    }, &auth);
    defer {
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
    const query = try req.query();
    const code = query.get("code");
    if (code) |c| {
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
            \\  <h2 style="color: white">Авторизация успешна!</h2>
            \\  <p style="color: white">Теперь эту вкладку можно закрыть.</p>
            \\</body>
            \\</html>
        ;

        if (server) |s| {
            s.stop();
            h.code = try h.allocator.dupe(u8, c);
        }
    }
}
