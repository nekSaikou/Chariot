const std = @import("std");
const util = @import("util.zig");
const getBit = @import("util.zig").getBit;
const setBit = @import("util.zig").setBit;
const popBit = @import("util.zig").popBit;
const pieceBB = @import("util.zig").pieceBB;
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const genPseudoLegal = @import("moves.zig").genPseudoLegal;
const makeMove = @import("moves.zig").makeMove;

var nodes: usize = 0;

fn perft(board_: *Board, depth: usize) void {
    @setEvalBranchQuota(5000000);

    var board: *Board = board_;
    const boardCopy: Board = board.*;

    if (depth == 0) {
        nodes += 1;
        return;
    }

    var moveList: MoveList = .{};
    genPseudoLegal(board.*, &moveList);

    for (0..moveList.count) |count| {
        if (!makeMove(board, moveList.moves[count], true)) continue;
        perft(board, depth - 1);
        board.* = boardCopy;
    }
}

pub fn perftTest(board_: *Board, depth: usize) !void {
    @setEvalBranchQuota(5000000);

    var board: *Board = board_;
    var moveList: MoveList = .{};
    genPseudoLegal(board.*, &moveList);

    var timer = try std.time.Timer.start();
    for (0..moveList.count) |count| {
        const boardCopy = board.*;

        if (!makeMove(board, moveList.moves[count], true)) continue;
        var cumulativeNodes: usize = nodes;
        perft(board, depth - 1);
        var oldNodes: usize = nodes - cumulativeNodes;
        board.* = boardCopy;

        std.debug.print("{s}: {d}\n", .{ util.uciMove(moveList.moves[count]), oldNodes });
    }
    std.debug.print("time taken: {}ms\n", .{timer.read() / 1000000});
    std.debug.print("nodes: {}\n", .{nodes});
    nodes = 0;
}
