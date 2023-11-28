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
const uci = @import("uci.zig");
const evaluate = @import("eval.zig").evaluate;

pub fn main() !void {
    atk.initAll();
    const debug: bool = false;
    if (!debug)
        try uci.mainLoop()
    else {
        var board: Board = undefined;
        try board.parseFEN("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8  ");
        std.debug.print("score: {d}\n", .{evaluate(board)});
    }
}
