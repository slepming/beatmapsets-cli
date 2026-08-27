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

    const zli_root = try zli.Command.init(init_options, .{
        .name = "beatmapset-cli",
        .description = "osu! CLI application for listing/search/download beatmapsets",
    }, showHelp);

    const get_beatmapsets_command = try zli.Command.init(init_options, .{ .name = "get-beatmapsets", .shortcut = "gb", .description = "Get beatmapsets from osu! api v2 with oauth." }, getBeatmapsets);

    try get_beatmapsets_command.addPositionalArg(.{
        .required = true,
        .description = "Search query.",
        .name = "Query",
    });

    try zli_root.addCommand(get_beatmapsets_command);

    // _ = try api.auth_client(init.io, allocator, "", 53, 3000, "public");
    // std.log.debug("received code", .{});
    var args_iter = init.minimal.args.iterate();
    zli_root.runAndExit(&args_iter, .{});
}

fn showHelp(ctx: zli.CommandContext) !void {
    try ctx.command.printHelp();
}

fn getBeatmapsets(ctx: zli.CommandContext) !void {
    ctx.positional_args
    try ctx.command.printHelp();
}
