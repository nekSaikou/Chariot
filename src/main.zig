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

pub fn main() !void {
    atk.initAll();
    try uci.mainLoop();
}
