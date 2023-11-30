const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;

pub fn main() !void {
    atk.initAll();
    var board: Board = undefined;
    try board.parseFEN("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8  ");
    std.debug.print("0x{x}\n", .{board.pieces[0]});
}
