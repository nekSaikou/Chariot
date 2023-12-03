const std = @import("std");
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;
const atk = @import("attacks.zig");
const Move = @import("types.zig").Move;
const ScoredMove = @import("types.zig").ScoredMove;
const MoveList = @import("types.zig").MoveList;
const Board = @import("types.zig").Board;
const Square = @import("types.zig").Square;

pub inline fn uciMove(move: Move) []const u8 {
    const src: []const u8 = @tagName(@as(Square, @enumFromInt(move.src)));
    const dest: []const u8 = @tagName(@as(Square, @enumFromInt(move.dest)));

    var output: [5]u8 = undefined;
    std.mem.copy(u8, output[0..], src);
    std.mem.copy(u8, output[2..], dest);

    if (move.promo == 0) return output[0..4];

    const promo: []const u8 = "n";
    std.mem.copy(u8, output[4..], promo);
    return output[0..5];
}
