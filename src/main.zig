const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const perft = @import("perft.zig").perftTest;
const makeMove = @import("makemove.zig").makeMove;

pub fn main() !void {
    atk.initAll();
    var board: Board = .{};
    try board.parseFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ");

    //makeMove(&board, Move{
    //    .src = 51,
    //    .dest = 35,
    //    .flag = 1,
    //    .piece = 0,
    //    .color = 0,
    //});

    try perft(&board, 7);
}
