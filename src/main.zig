const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const perft = @import("perft.zig").perftTest;
const makeMove = @import("makemove.zig").makeMove;
const initRandomKeys = @import("zobrist.zig").initRandomKeys;
const uci = @import("uci.zig");

pub fn main() !void {
    atk.initAll();
    initRandomKeys();

    try uci.mainLoop();
}
