const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const genLegal = @import("movegen.zig").genLegal;
const printBB = @import("bitboard.zig").printBitboard;
const makeMove = @import("makemove.zig").makeMove;
const uci = @import("uci.zig");

var nodes: usize = 0;

fn perftDriver(board_: *Board, depth: usize) void {
    @setEvalBranchQuota(5000000);

    var board: *Board = board_;
    const board_copy: Board = board.*;

    if (depth == 0) {
        nodes += 1;
        return;
    }

    var list: MoveList = .{};
    genLegal(board, &list);

    for (0..list.count) |count| {
        makeMove(board, list.moves[count].move);
        perftDriver(board, depth - 1);
        board.* = board_copy;
    }
}

pub fn perftTest(board_: *Board, depth: usize) !void {
    @setEvalBranchQuota(5000000);

    var board: *Board = board_;
    var list: MoveList = .{};
    genLegal(board, &list);

    var timer = try std.time.Timer.start();
    for (0..list.count) |count| {
        const board_copy = board.*;

        makeMove(board, list.moves[count].move);
        var cumulativeNodes: usize = nodes;
        perftDriver(board, depth - 1);
        var oldNodes: usize = nodes - cumulativeNodes;
        board.* = board_copy;

        std.debug.print("{s}: {d}\n", .{ uci.uciMove(list.moves[count].move), oldNodes });
    }
    std.debug.print("time taken: {}ms\n", .{timer.read() / 1000000});
    std.debug.print("nodes: {}\n", .{nodes});
    nodes = 0;
}
