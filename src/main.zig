const std = @import("std");
const api = @import("osu_api");
const Io = std.Io;

const beatmapsets_cli = @import("beatmapsets_cli");

pub fn main(init: std.process.Init) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var args_iter = try init.minimal.args.iterateAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.next();
    const program_id = try std.fmt.parseInt(u64, args_iter.next().?, 10);
    const client_secret = args_iter.next().?;
    _ = try api.auth_client(init.io, allocator, client_secret, program_id, 3000, "public");
    std.log.debug("code received", .{});
}
