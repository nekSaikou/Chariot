const std = @import("std");
const Square = @import("types.zig").Square;
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;

pub inline fn pieceBB(board: Board, piece: u3, color: u1) u64 {
    return board.pieces[piece] & board.occupancy[color];
}

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

pub inline fn uciMove(move: Move) []const u8 {
    const src: []const u8 = @tagName(@as(Square, @enumFromInt(move.src)));
    const dest: []const u8 = @tagName(@as(Square, @enumFromInt(move.dest)));

    var output: [5]u8 = undefined;
    std.mem.copy(u8, output[0..], src);
    std.mem.copy(u8, output[2..], dest);

    if (move.promo == 0) return output[0..4];

    const promo: []const u8 = switch (move.promo) {
        0 => " ",
        1 => "n",
        2 => "b",
        3 => "r",
        4 => "q",
        else => unreachable,
    };
    std.mem.copy(u8, output[4..], promo);
    return output[0..5];
}
