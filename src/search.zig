const std = @import("std");
const stdout = std.io.getStdOut().writer();
const util = @import("util.zig");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const moves = @import("moves.zig");
const evaluate = @import("eval.zig").evaluate;
const uci = @import("uci.zig");

const MAX_PLY: usize = 200;
const CHECKMATE: i32 = 49000;

var bestMove: Move = .{ .src = 0, .dest = 0, .piece = 0 };
var nodes: usize = 0;

pub fn negamax(alpha_: i32, beta_: i32, depth_: i8, board: *Board) i32 {
    @setEvalBranchQuota(5000000);
    var alpha = alpha_;
    var beta = beta_;
    var depth = depth_;

    // prune mate
    if (board.ply != 0) {
        alpha = @max(alpha, -CHECKMATE + board.ply);
        beta = @min(beta, CHECKMATE + board.ply - 1);
    }
    if (alpha >= beta) return alpha;

    if (depth == 0) return evaluate(board.*);

    nodes += 1;

    var currentBest: Move = .{ .src = 0, .dest = 0, .piece = 0 };

    var legalCount: usize = 0;
    var attacksOnKing: u64 = atk.getAttackers(board.*, board.kingSqr(board.side), board.side ^ 1);
    // increase depth if either king is in check
    if (attacksOnKing != 0) depth += 1;

    var moveList: MoveList = .{};
    moves.genPseudoLegal(board.*, &moveList);

    for (0..moveList.count) |count| {
        const boardCopy: Board = board.*;
        board.ply += 1;

        if (!moves.makeMove(board, moveList.moves[count], true)) {
            board.ply -= 1;
            continue;
        }

        legalCount += 1;

        var score: i32 = -negamax(-beta, -alpha, depth - 1, board);

        board.* = boardCopy;

        if (score >= beta) {
            return beta;
        }
        if (score > alpha) {
            alpha = score;
            if (board.ply == 0)
                currentBest = moveList.moves[count];
        }
    }

    if (legalCount == 0) {
        if (attacksOnKing != 0) return -CHECKMATE + @as(i32, @intCast(board.ply));
        return 0;
    }

    if (alpha != alpha_) bestMove = currentBest;
    return alpha;
}

pub fn searchPos(board: *Board, depth: i8) !void {
    var score: i32 = negamax(-50000, 50000, depth, board);
    if (@as(u22, @bitCast(bestMove)) != 0) {
        try stdout.print("info score cp {} depth {} nodes {}\n", .{ score, depth, nodes });
        std.debug.print("nodes: {}\n", .{nodes});
        nodes = 0;
        try uci.printBestMove(bestMove);
    }
}
