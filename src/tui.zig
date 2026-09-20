const zz = @import("zigzag");
const std = @import("std");
const authorization = @import("beatmapsets_cli").token;
const main = @import("main.zig");

const Focus = enum {
    SearchBeatmapsetTable,
    SearchBeatmapsetTextArea,
};

pub const Model = struct {
    selected_panel: u8,
    beatmapset_table: zz.components.DataTable,
    beatmapset_query_text_area: zz.components.TextArea,
    error_message: ?[]const u8 = null,
    current_token: ?authorization.Token = null,
    error_limit: u8 = 3,

    pub const Msg = union(enum) {
        key: zz.KeyEvent,
    };

    const table_headers = [_]zz.components.DataColumn{
        .{ .header = "id", .width = 15, .@"align" = .right },
        .{ .header = "title", .width = 30 },
        .{ .header = "artist", .width = 20 },
        .{ .header = "creator", .width = 20 },
        .{ .header = "status", .width = 15 },
        .{ .header = "bpm", .width = 8, .@"align" = .right },
        .{ .header = "anime cover?", .width = 12, .@"align" = .right },
    };

    var table_rows: std.ArrayList([]const []const u8) = .empty;

    pub fn init(self: *Model, ctx: *zz.Context) !zz.Cmd(Msg) {
        var t = zz.components.DataTable.init(ctx.persistent_allocator);
        try t.setColumns(&table_headers);
        try t.setRows(table_rows.items);
        t.setSize(60, 15);
        t.setFrozenColumns(2);

        var query_text_area = zz.components.TextArea.init(ctx.persistent_allocator);
        query_text_area.placeholder = "Query";

        self.* = .{
            .selected_panel = 0,
            .beatmapset_table = t,
            .beatmapset_query_text_area = query_text_area,
        };

        if (self.current_token == null) {
            try self.refresh_token(ctx.persistent_allocator, ctx.io);
        }

        return .none;
    }

    fn refresh_token(
        self: *Model,
        allocator: std.mem.Allocator,
        io: std.Io,
    ) !void {
        self.refresh_token_env(allocator, io) catch |err| {
            if (err == error.ClientInvalid) {
                try self.refresh_token_tui(allocator, io);
            }
        };
    }

    fn refresh_token_tui(
        _: *Model,
        _: std.mem.Allocator,
        _: std.Io,
    ) !void {
        return error.NotImplemented;
    }

    fn refresh_token_env(
        self: *Model,
        allocator: std.mem.Allocator,
        io: std.Io,
    ) !void {
        var http_client = std.http.Client{ .allocator = allocator, .io = io };
        defer http_client.deinit();

        const client_id_raw = std.c.getenv("OSU_API_CLIENT_ID") orelse return error.ClientInvalid;
        const client_secret_raw = std.c.getenv("OSU_API_CLIENT_SECRET") orelse return error.ClientInvalid;

        const client_id: []const u8 = std.mem.span(client_id_raw);
        const client_secret: []const u8 = std.mem.span(client_secret_raw);

        self.current_token = main.authorization(io, allocator, client_secret, std.fmt.parseInt(u64, client_id, 10) catch 0, false) catch {
            return error.TokenInvalid;
        };
    }

    pub fn update(self: *Model, msg: Msg, ctx: *zz.Context) zz.Cmd(Msg) {
        switch (msg) {
            .key => |k| switch (k.key) {
                .char => |c| switch (c) {
                    'q' => return .quit,
                    '1' => self.selected_panel = 0,
                    '2' => {
                        self.selected_panel = 1;
                        table_rows.clearAndFree(ctx.allocator);

                        var http_client = std.http.Client{ .allocator = ctx.allocator, .io = ctx.io };
                        defer http_client.deinit();

                        if (self.current_token) |token| {
                            const beatmapsets = main.api.beatmapsets.BeatmapsetSearch.request(ctx.allocator, &http_client, &token, null) catch {
                                self.error_message = "Search beatmapset request error";
                                return .quit;
                            };

                            for (beatmapsets.beatmapsets) |beatmapset| {
                                const row = ctx.allocator.create([7][]const u8) catch {
                                    self.error_message = "Out of memory error";
                                    return .quit;
                                };

                                const beatmapset_id = std.fmt.allocPrint(ctx.allocator, "{d}", .{beatmapset.id}) catch "out of memory";
                                const beatmapset_bpm = std.fmt.allocPrint(ctx.allocator, "{any}", .{beatmapset.bpm}) catch "out of memory";

                                row.* = .{
                                    beatmapset_id,
                                    beatmapset.title,
                                    beatmapset.artist,
                                    beatmapset.creator,
                                    beatmapset.status,
                                    beatmapset_bpm,
                                    if (beatmapset.anime_cover) "Yes" else "No",
                                };

                                table_rows.append(
                                    ctx.allocator,
                                    row,
                                ) catch return .quit;
                            }

                            self.beatmapset_table.setRows(table_rows.items) catch {
                                self.error_message = "Setting rows for table error";
                                return .quit;
                            };
                        } else {
                            self.refresh_token(ctx.persistent_allocator, ctx.io) catch {
                                self.error_message = "Token invalid";
                                return .quit;
                            };
                        }
                    },
                    else => self.beatmapset_table.handleKey(k),
                },
                .tab => {
                    self.selected_panel = (self.selected_panel + 1) % 3;
                },
                .escape => return .quit,
                else => {},
            },
        }
        return .none;
    }

    pub fn view(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        const alloc = ctx.allocator;
        const w: u16 = @intCast(@min(ctx.width, std.math.maxInt(u16)));
        const h: u16 = @intCast(@min(ctx.height, std.math.maxInt(u16)));

        var table_mut = @constCast(&self.beatmapset_table);
        var query_text_area_mut = @constCast(&self.beatmapset_query_text_area);

        // Outer vertical layout: header(3) | body(fill) | footer(3)
        const rows = zz.flex.layout(alloc, w, h, &.{
            .{ .constraint = .{ .fixed = 3 } },
            .{ .constraint = .fill },
            .{ .constraint = .{ .fixed = 3 } },
        }, .{ .direction = .column }) catch return "layout error";

        // Body horizontal layout: sidebar(20%) | main(fill)
        const cols = zz.flex.layout(alloc, rows[1].width, rows[1].height, &.{
            .{ .constraint = .{ .percentage = 20 } },
            .{ .constraint = .fill },
        }, .{ .direction = .row, .gap = 1 }) catch return "layout error";

        table_mut.setSize(cols[1].width, cols[1].height - 30);
        const table_view = table_mut.view(alloc) catch {
            return "The process of getting the table view caused an error";
        };

        query_text_area_mut.setSize(cols[1].width, cols[1].height - (cols[1].height - 2));
        const query_text_area_view = try query_text_area_mut.view(alloc);

        const beatmapsets_content = try std.fmt.allocPrint(alloc, "{s}\n\n{s}", .{ query_text_area_view, table_view });

        // -- Render each panel into styled boxes --

        // Header
        const header = renderPanel(
            alloc,
            std.fmt.allocPrint(alloc, "beatmapsets-cli TUI {s}", .{main.VERSION}) catch "",
            rows[0].width,
            rows[0].height,
            zz.Color.brightMagenta,
            true,
        );

        // Sidebar
        const sidebar_items =
            "  [1] Overview\n" ++
            "  [2] Beatmapsets\n" ++
            "  [3] WIP";
        const sidebar = renderPanel(alloc, sidebar_items, cols[0].width, cols[0].height, zz.Color.magenta, self.selected_panel == 0);

        // Main content area
        const main_text = switch (self.selected_panel) {
            0 => main.DESCRIPTION,
            1 => beatmapsets_content,
            else => "",
        };

        const main_panel = renderPanel(alloc, main_text, cols[1].width, cols[1].height, zz.Color.green, self.selected_panel == 1);

        // Footer
        var help_style = zz.Style{};
        help_style = help_style.fg(zz.Color.gray(12));
        help_style = help_style.inline_style(true);
        const footer_text = try help_style.render(
            alloc,
            std.fmt.allocPrint(alloc, "Tab: cycle panels  1/2/3: select panel  q: quit        {any} fps", .{ctx.fps()}) catch return "OUT OF MEMORY",
        );
        const footer = renderPanel(alloc, footer_text, rows[2].width, rows[2].height, zz.Color.gray(8), false);

        // Compose the body row: sidebar | main
        const body = try zz.join.horizontal(alloc, .top, &.{ sidebar, main_panel });

        // Stack vertically
        return zz.join.vertical(alloc, .left, &.{ header, body, footer });
    }

    fn renderPanel(alloc: std.mem.Allocator, content: []const u8, w: u16, h: u16, border_color: zz.Color, highlight: bool) []const u8 {
        var s = zz.Style{};
        s = s.borderAll(zz.Border.rounded);
        if (highlight) {
            s = s.borderForeground(border_color);
        } else {
            s = s.borderForeground(zz.Color.gray(6));
        }
        // Account for border (2 cells each side)
        const inner_w: u16 = if (w > 4) w - 4 else 1;
        const inner_h: u16 = if (h > 2) h - 2 else 1;
        s = s.width(inner_w);
        s = s.height(inner_h);
        return s.render(alloc, content) catch content;
    }
};
