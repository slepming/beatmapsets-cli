const std = @import("std");
const api = @import("osu_api");
const zli = @import("zli");

const Io = std.Io;

const beatmapsets_cli = @import("beatmapsets_cli");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client_secret: []const u8 = undefined;
    var client_id: u64 = undefined;

    var wbuf: [1024]u8 = undefined;
    var stdout_writer = Io.File.Writer.init(.stdout(), io, &wbuf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var rbuf: [1024]u8 = undefined;
    var stdin_reader = Io.File.Reader.init(.stdout(), io, &rbuf);
    const stdin = &stdin_reader.interface;

    const init_options = zli.InitOptions{
        .allocator = allocator,
        .io = io,
        .reader = stdin,
        .writer = stdout,
    };

    _ = try api.auth_client(init.io, allocator, client_secret, client_id, 3000, "public");
    std.log.debug("received code", .{});
}
