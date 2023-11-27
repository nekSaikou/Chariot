const std = @import("std");
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

const Square = enum(u6) {
    // zig fmt: off
    a8, b8, c8, d8, e8, f8, g8, h8,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a1, b1, c1, d1, e1, f1, g1, h1
    // zig fmt: on
};
