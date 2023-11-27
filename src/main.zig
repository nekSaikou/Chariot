const std = @import("std");
const util = @import("util.zig");
const getBit = @import("util.zig").getBit;
const setBit = @import("util.zig").setBit;
const popBit = @import("util.zig").popBit;
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const moves = @import("moves.zig");
const perftTest = @import("perft.zig").perftTest;

pub fn main() !void {
    atk.initAll();
    var board: Board = undefined;
    try board.parseFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    //_ = moves.makeMove(
    //    &board,
    //    Move{
    //        .src = 45,
    //        .dest = 21,
    //        .piece = 4,
    //        .capture = 1,
    //    },
    //    true,
    //);

    try perftTest(&board, 5);

    // moves.genPseudoLegal(board, &moveList);
    // for (0..moveList.count) |count| {
    //     std.debug.print("{any}\n", .{moveList.moves[count]});
    // }
    // std.debug.print("count: {d}\n", .{moveList.count});
    // _ = moves.makeMove(&board, moveList.moves[2], true);
}
