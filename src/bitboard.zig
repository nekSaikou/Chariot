const std = @import("std");
const Square = @import("types.zig").Square;
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;

pub inline fn setBit(bitboard: *u64, square: u6) void {
    bitboard.* |= (@as(u64, 1) << square);
}

pub inline fn popBit(bitboard: *u64, square: u6) void {
    if (getBit(bitboard.*, square) == 1)
        bitboard.* ^= (@as(u64, 1) << square);
}

pub inline fn getBit(bitboard: u64, square: u6) u2 {
    if (bitboard & (@as(u64, 1) << @intCast(square)) != 0)
        return 1;
    return 0;
}

pub fn printBitboard(bitboard: u64) void {
    for (0..8) |rank| {
        for (0..8) |file| {
            var square: usize = rank * 8 + file;
            std.debug.print("{} ", .{getBit(bitboard, @intCast(square))});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\nBitboard: 0x{x}\n\n\n", .{bitboard});
}
