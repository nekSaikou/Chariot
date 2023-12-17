const std = @import("std");
const Square = @import("types.zig").Square;
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;

pub inline fn setBit(bitboard: *u64, square: u6) void {
    bitboard.* |= (@as(u64, 1) << square);
}

pub inline fn popBit(bitboard: *u64, square: u6) void {
    bitboard.* ^= (@as(u64, 1) << square);
}

pub inline fn getBit(bitboard: u64, square: u6) u64 {
    return bitboard & (@as(u64, 1) << @intCast(square));
}

pub fn printBitboard(bitboard: u64) void {
    for (0..8) |rank| {
        for (0..8) |file| {
            var square: usize = rank * 8 + file;
            const bit: u1 = switch (getBit(bitboard, @intCast(square))) {
                0 => 0,
                else => 1,
            };
            std.debug.print("{} ", .{bit});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\nBitboard: 0x{x}\n\n\n", .{bitboard});
}
