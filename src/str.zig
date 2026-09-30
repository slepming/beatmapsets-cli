const std = @import("std");
const mem = std.mem;

pub fn from(comptime T: type, buffer: []u8, integer: T) ![]const u8 {
    return try std.fmt.bufPrint(buffer, "{}", .{integer});
}

pub fn from_alloc(comptime T: type, allocator: std.mem.Allocator, integer: T) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{}", .{integer});
}

test "convert" {
    const ascii = &[_]u8{ '2', '3', '0' };
    const ascii_less = &[_]u8{ '1', '0', '0' };
    const ascii_more = &[_]u8{ '2', '0', '0', '0', '0', '0' };
    var buffer: [128]u8 = undefined;
    const integer_u8: u8 = 230;
    const integer_i8: i8 = 100;
    const integer_u32: u32 = 200000;
    const integer_i32: i32 = 200000;

    try std.testing.expectEqualStrings(ascii, try from(u8, &buffer, integer_u8));
    try std.testing.expectEqualStrings(ascii_less, try from(i8, &buffer, integer_i8));
    try std.testing.expectEqualStrings(ascii_more, try from(u32, &buffer, integer_u32));
    try std.testing.expectEqualStrings(ascii_more, try from(i32, &buffer, integer_i32));
}
