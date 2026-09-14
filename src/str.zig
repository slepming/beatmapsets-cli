const std = @import("std");
const mem = std.mem;

pub fn from_i8(buffer: []u8, integer: i8) []const u8 {
    var current: u8 = 0;
    if (integer < 0) {
        current = @intCast(integer * -1);
    } else current = @intCast(integer);
    return from_u8(buffer, current);
}

pub fn from_u8(buffer: []u8, integer: u8) []const u8 {
    var current: u8 = integer;
    var _buffer: [16]u8 = undefined;

    const ascii_shift: u8 = 0x30;
    const divider: u8 = 0xA;
    var i: u8 = 0x0;
    while (current / divider != 0x0) : (i +%= 1) {
        _buffer[i] = (current % divider) + ascii_shift;
        current = current / divider;
    }
    _buffer[i] = current + ascii_shift;
    i +%= 1;

    mem.reverse(u8, _buffer[0..i]);

    @memcpy(buffer[0..i], _buffer[0..i]);

    return buffer[0..i];
}

test "convert i8 to ascii" {
    const ascii = &[_]u8{ '1', '0', '0' };
    var buffer: [128]u8 = undefined;
    const integer: i8 = 100;

    try std.testing.expectEqualStrings(ascii, from_i8(&buffer, integer));
}

test "convert u8 to ascii" {
    const ascii = &[_]u8{ '2', '3', '0' };
    var buffer: [128]u8 = undefined;
    const integer: u8 = 230;

    try std.testing.expectEqualStrings(ascii, from_u8(&buffer, integer));
}
