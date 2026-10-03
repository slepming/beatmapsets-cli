const zz = @import("zigzag");
const std = @import("std");
const authorization = @import("beatmapsets_cli").token;
const main = @import("main.zig");

const Menu = enum {
    Overview,
    SearchBeatmapsets,
};

pub const Model = struct {
    menu_position: Menu,
    beatmapset_table: zz.components.DataTable,
    error_message: ?[]const u8 = null,
    current_token: ?authorization.Token = null,
    error_limit: u8 = 3,
    areas: std.StringHashMap(zz.components.TextArea),
    writer_alloc: std.Io.Writer.Allocating,

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
        query_text_area.placeholder = "Query(for enter text press 'i')";

        self.* = .{
            .menu_position = .Overview,
            .beatmapset_table = t,
            .areas = .init(ctx.persistent_allocator),
            .writer_alloc = std.Io.Writer.Allocating.init(ctx.persistent_allocator),
        };

        try self.areas.put("beatmapset_query_text_area", query_text_area);

        if (self.current_token == null) {
            try self.refreshToken(ctx.persistent_allocator, ctx.io);
        }

        return .none;
    }

    pub fn update(self: *Model, msg: Msg, ctx: *zz.Context) zz.Cmd(Msg) {
        const _area = self.areas.getPtr("beatmapset_query_text_area");
        switch (msg) {
            .key => |k| {
                if (self.menu_position == .SearchBeatmapsets) {
                    if (_area) |area| {
                        area.handleKey(k);
                        if (!area.focused) {
                            self.beatmapset_table.handleKey(k);
                        }
                    }
                }
                if (k.modifiers.ctrl) {
                    switch (k.key) {
                        .char => |c| switch (c) {
                            'q' => return .quit,
                            'o' => self.menu_position = @enumFromInt(0),
                            's' => {
                                self.menu_position = @enumFromInt(1);
                                self.searchBeatmapsets(ctx) catch return .quit;
                            },
                            'l' => {
                                self.menu_position = @enumFromInt((@intFromEnum(self.menu_position) +% 1));
                                if (self.menu_position == .SearchBeatmapsets) self.searchBeatmapsets(ctx) catch {
                                    return .none;
                                };
                            },
                            'h' => {
                                self.menu_position = @enumFromInt((@intFromEnum(self.menu_position) -% 1));
                                if (self.menu_position == .SearchBeatmapsets) self.searchBeatmapsets(ctx) catch {
                                    return .none;
                                };
                            },
                            else => {
                                return .none;
                            },
                        },
                        else => {
                            return .none;
                        },
                    }
                }
                switch (k.key) {
                    .char => |e| {
                        switch (e) {
                            'i' => {
                                if (self.menu_position == .SearchBeatmapsets) {
                                    if (_area) |area| {
                                        area.focus();
                                    }
                                }
                            },
                            else => {
                                return .none;
                            },
                        }
                    },
                    .backspace => {},
                    .tab => {
                        self.menu_position = @enumFromInt((@intFromEnum(self.menu_position) +% 1));
                        if (self.menu_position == .SearchBeatmapsets) self.searchBeatmapsets(ctx) catch |err| {
                            std.log.err("{}", .{err});
                            return .quit;
                        };
                    },
                    .escape => {
                        if (self.menu_position == .SearchBeatmapsets) {
                            if (_area) |area| {
                                area.blur();
                            }
                        }
                    },
                    else => {},
                }
            },
        }

        return .none;
    }

    fn searchBeatmapsets(self: *Model, ctx: *zz.Context) !void {
        table_rows.clearAndFree(ctx.allocator);

        var http_client = std.http.Client{ .allocator = ctx.allocator, .io = ctx.io };
        defer http_client.deinit();

        if (self.current_token) |token| {
            const response = main.api.beatmapsets.BeatmapsetSearch.request(ctx.allocator, &http_client, &self.writer_alloc, &token, null) catch |err| {
                self.error_message = try std.fmt.allocPrint(ctx.allocator, "{s}: {}", .{ "Search beatmapset request error", err });
                return err;
            };

            if (response.value.beatmapsets) |beatmapsets| {
                for (beatmapsets) |beatmapset| {
                    const row = ctx.allocator.create([7][]const u8) catch |err| {
                        self.error_message = "Out of memory error";
                        return err;
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

                    try table_rows.append(
                        ctx.allocator,
                        row,
                    );
                }
            }

            self.beatmapset_table.setRows(table_rows.items) catch |err| {
                self.error_message = "Setting rows for table error";
                return err;
            };
        } else {
            self.refreshToken(ctx.persistent_allocator, ctx.io) catch |err| {
                self.error_message = "Token invalid";
                return err;
            };
        }
    }

    pub fn view(self: *const Model, ctx: *const zz.Context) ![]const u8 {
        if (self.error_message) |err_msg| {
            return err_msg;
        }

        const alloc = ctx.allocator;
        const w: u16 = @intCast(@min(ctx.width, std.math.maxInt(u16)));
        const h: u16 = @intCast(@min(ctx.height, std.math.maxInt(u16)));

        var table_mut = @constCast(&self.beatmapset_table);
        var query_text_area_mut = @constCast(&self.areas.get("beatmapset_query_text_area").?);

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

        table_mut.setSize(cols[1].width - cols[1].width / 10, cols[1].height - 30);
        const table_view = table_mut.view(alloc) catch {
            return "The process of getting the table view caused an error";
        };

        query_text_area_mut.setSize(cols[1].width - cols[1].width / 10, cols[1].height - (cols[1].height - 2));
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
        const sidebar = renderPanel(alloc, sidebar_items, cols[0].width, cols[0].height, zz.Color.magenta, self.menu_position == .Overview);

        // Main content area
        const main_text = switch (self.menu_position) {
            .Overview => main.DESCRIPTION,
            .SearchBeatmapsets => beatmapsets_content,
        };

        const main_panel = renderPanel(alloc, main_text, cols[1].width, cols[1].height, zz.Color.green, self.menu_position == .SearchBeatmapsets);

        // Footer
        var help_style = zz.Style{};
        help_style = help_style.fg(zz.Color.gray(12));
        help_style = help_style.inline_style(true);
        const footer_text = try help_style.render(
            alloc,
            std.fmt.allocPrint(alloc, "Tab/C-{{h,l}}: cycle panels  C-s: search beatmapsets  C-q: quit        {any} fps", .{ctx.fps()}) catch return "OUT OF MEMORY",
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

    fn refreshToken(
        self: *Model,
        allocator: std.mem.Allocator,
        io: std.Io,
    ) !void {
        self.refreshTokenEnv(allocator, io) catch |err| {
            if (err == error.ClientInvalid) {
                self.menu_position = @enumFromInt(0);
            }
        };
    }

    fn refreshTokenEnv(
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

    fn refreshTokenTui(self: *Model, alloc: std.mem.Allocator, w: u16, h: u16) ![]const u8 {
        const content = zz.flex.layout(
            alloc,
            w,
            h,
            &.{
                .{ .constraint = .{ .percentage = 40 } },
                .{ .constraint = .{ .percentage = 40 } },
                .{ .constraint = .{.fill} },
            },
            .{ .direction = .row, .gap = 1 },
        ) catch return "layout error";

        var client_id_area = zz.components.TextArea.init(alloc);
        client_id_area.setSize(content[0].width, content[0].height);
        client_id_area.placeholder = "id";
        var client_secret_area = zz.components.TextArea.init(alloc);
        client_secret_area.setSize(content[1].width, content[1].height);
        client_secret_area.placeholder = "secret";

        self.areas.put("client_id", client_id_area);
        self.areas.put("client_secret", client_secret_area);
    }
};
