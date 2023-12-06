const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const perft = @import("perft.zig").perftTest;
const makeMove = @import("makemove.zig").makeMove;
const initRandomKeys = @import("zobrist.zig").initRandomKeys;
const initTT = @import("ttable.zig").initTT;
const search = @import("search.zig").searchPos;
const uci = @import("uci.zig");

pub fn main() !void {
    atk.initAll();
    initRandomKeys();
    initTT(16);

    try uci.mainLoop();
}
