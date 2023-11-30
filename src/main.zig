const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const genPsuedoLegal = @import("movegen.zig").genPseudoLegal;

pub fn main() !void {
    atk.initAll();
    var board: Board = .{};
    try board.parseFEN("rnbqkbnr/pppppppp/8/8/8/8/PPP11PPP/RNBQK11R w KQkq - 0 1 ");

    var list: MoveList = .{};
    genPsuedoLegal(board, &list);

    for (0..list.count) |count| {
        std.debug.print("{any}\n", .{list.moves[count]});
    }
}
