const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const movegen = @import("movegen.zig");
const printBB = @import("bitboard.zig").printBitboard;
const makeMove = @import("makemove.zig").makeMove;
const uci = @import("uci.zig");

var nodes: usize = 0;

fn perftDriver(board_: *Board, depth: usize) void {
    @setEvalBranchQuota(5000000);

    var board: *Board = board_;
    const boardCopy: Board = board.*;

    if (depth == 0) {
        nodes += 1;
        return;
    }

    var move_list: MoveList = .{};
    movegen.genLegal(board, &move_list);

    for (0..move_list.count) |count| {
        makeMove(board, move_list.moves[count].move);
        perftDriver(board, depth - 1);
        board.* = boardCopy;
    }
}

pub fn perftTest(board_: *Board, depth: usize) !void {
    @setEvalBranchQuota(5000000);

    var board: *Board = board_;
    var move_list: MoveList = .{};
    movegen.genLegal(board, &move_list);

    var timer = try std.time.Timer.start();
    for (0..move_list.count) |count| {
        const boardCopy = board.*;

        makeMove(board, move_list.moves[count].move);
        var cumulativeNodes: usize = nodes;
        perftDriver(board, depth - 1);
        var oldNodes: usize = nodes - cumulativeNodes;
        board.* = boardCopy;

        std.debug.print("{s}: {d}\n", .{ uci.uciMove(move_list.moves[count].move), oldNodes });
    }
    std.debug.print("time taken: {}ms\n", .{timer.read() / 1000000});
    std.debug.print("nodes: {}\n", .{nodes});
    nodes = 0;
}
