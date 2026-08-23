const std = @import("std");
const api = @import("osu_api");
const Io = std.Io;

const beatmapsets_cli = @import("beatmapsets_cli");

pub fn main(init: std.process.Init) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = std.http.Client{
        .allocator = allocator,
        .io = init.io,
    };
    defer client.deinit();

    const beatmapset = try api.beatmapsets.BeatmapsetSearch.request(&client, "hwllo", allocator);
    std.log.debug("{}", .{
        beatmapset.total,
    });
}
