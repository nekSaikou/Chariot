const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const perft = @import("perft.zig").perftTest;
const makeMove = @import("makemove.zig").makeMove;
const initRandomKeys = @import("zobrist.zig").initRandomKeys;
const initTT = @import("ttable.zig").initTT;

pub fn main() !void {
    atk.initAll();
    initRandomKeys();
    initTT(16);

    var board: Board = .{};
    try board.parseFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ");
    try perft(&board, 7);
}
