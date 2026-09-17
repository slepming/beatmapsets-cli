const std = @import("std");
const mem = std.mem;

pub fn from_i8(buffer: []u8, integer: i8) ![]const u8 {
    return try std.fmt.bufPrint(buffer, "{}", .{integer});
}

pub fn from_u8(buffer: []u8, integer: u8) ![]const u8 {
    return try std.fmt.bufPrint(buffer, "{}", .{integer});
}

pub fn from_u32(buffer: []u8, integer: u32) ![]const u8 {
    return try std.fmt.bufPrint(buffer, "{}", .{integer});
}

pub fn from_i32(buffer: []u8, integer: i32) ![]const u8 {
    return try std.fmt.bufPrint(buffer, "{}", .{integer});
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

    try std.testing.expectEqualStrings(ascii, try from_u8(&buffer, integer_u8));
    try std.testing.expectEqualStrings(ascii_less, try from_i8(&buffer, integer_i8));
    try std.testing.expectEqualStrings(ascii_more, try from_u32(&buffer, integer_u32));
    try std.testing.expectEqualStrings(ascii_more, try from_i32(&buffer, integer_i32));
}
