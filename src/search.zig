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

var bestMove: Move = .{};
var nodes: usize = 0;

pub fn negamax(board: *Board, alpha_: i32, beta_: i32, depth_: i8) i32 {
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

    if (depth == 0) return quiesecense(board, alpha, beta);

    nodes += 1;

    var currentBest: Move = .{ .src = 0, .dest = 0, .piece = 0 };

    var legalCount: usize = 0;
    var attacksOnKing: u64 = atk.getAttackers(board.*, board.kingSqr(board.side), board.side ^ 1);
    // increase depth if either king is in check
    if (attacksOnKing != 0) depth += 1;

    var moveList: MoveList = .{};
    moves.genPseudoLegal(board.*, &moveList);

    sort(board.*, &moveList);

    for (0..moveList.count) |count| {
        const boardCopy: Board = board.*;
        board.ply += 1;

        if (!moves.makeMove(board, moveList.moves[count], true)) {
            board.ply -= 1;
            continue;
        }

        legalCount += 1;

        var score: i32 = -negamax(board, -beta, -alpha, depth - 1);

        board.* = boardCopy;

        if (score >= beta) {
            if (moveList.moves[count].capture == 0) {
                board.killer[@intCast(board.ply)][1] = board.killer[@intCast(board.ply)][0];
                board.killer[@intCast(board.ply)][0] = moveList.moves[count];
            }
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

fn quiesecense(board: *Board, alpha_: i32, beta: i32) i32 {
    @setEvalBranchQuota(5000000);

    var alpha: i32 = alpha_;

    var evaluation = evaluate(board.*);

    if (evaluation >= beta) return beta;
    if (evaluation > alpha) {
        alpha = evaluation;
    }

    nodes += 1;

    var moveList: MoveList = .{};
    moves.genPseudoLegal(board.*, &moveList);

    sort(board.*, &moveList);

    for (0..moveList.count) |count| {
        const boardCopy = board.*;
        board.ply += 1;

        if (!moves.makeMove(board, moveList.moves[count], false)) {
            board.ply -= 1;
            continue;
        }

        var score: i32 = -quiesecense(board, -beta, -alpha);

        board.ply -= 1;

        board.* = boardCopy;

        if (score >= beta) return beta;
        if (score > alpha) {
            alpha = score;
        }
    }
    return alpha;
}

inline fn sort(board: Board, moveList: *MoveList) void {
    var moveScore: [1024]i32 = undefined;
    for (0..moveList.count) |count| {
        moveScore[count] = scoreMove(board, moveList.moves[count]);
    }
    for (0..moveList.count) |current| {
        for (current..moveList.count + 1) |next| {
            if (moveScore[current] < moveScore[next]) {
                var tmp: i32 = moveScore[current];
                moveScore[current] = moveScore[next];
                moveScore[next] = tmp;

                var tmp_mv: Move = moveList.moves[current];
                moveList.moves[current] = moveList.moves[next];
                moveList.moves[next] = tmp_mv;
            }
        }
    }
}

inline fn scoreMove(board: Board, move: Move) i32 {
    if (move.capture == 1) {
        // score by MMV-LVA
        for (0..6) |victim| {
            if (util.getBit(board.occupancy[board.side ^ 1] & board.pieces[victim], move.dest) == 1) {
                return MVV_LVA[move.piece][victim];
            }
        }
    } else {
        // score killer moves
        if (@as(u22, @bitCast(board.killer[@intCast(board.ply)][0])) == @as(u22, @bitCast(move))) return 9000;
        if (@as(u22, @bitCast(board.killer[@intCast(board.ply)][1])) == @as(u22, @bitCast(move))) return 8000;
        return board.moveScoreHistory[move.piece][move.dest];
    }
    return 0;
}

pub fn searchPos(board: *Board, depth: i8) !void {
    var score: i32 = negamax(board, -50000, 50000, depth);
    if (@as(u22, @bitCast(bestMove)) != 0) {
        try stdout.print("info score cp {} depth {} nodes {}\n", .{ score, depth, nodes });
        std.debug.print("nodes: {}\n", .{nodes});
        nodes = 0;
        try uci.printBestMove(bestMove);
    }
}

const MVV_LVA = [6][6]i32{
    [6]i32{ 105, 205, 305, 405, 505, 605 },
    [6]i32{ 104, 204, 304, 404, 504, 604 },
    [6]i32{ 103, 203, 303, 403, 503, 603 },
    [6]i32{ 102, 202, 302, 402, 502, 602 },
    [6]i32{ 101, 201, 301, 401, 501, 601 },
    [6]i32{ 100, 200, 300, 400, 500, 600 },
};
