const std = @import("std");
const stdout = std.io.getStdOut().writer();
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const ScoredMove = @import("types.zig").ScoredMove;
const MoveList = @import("types.zig").MoveList;
const MoveType = @import("types.zig").MoveType;
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;
const genLegal = @import("movegen.zig").genLegal;
const makeMove = @import("makemove.zig").makeMove;
const evaluate = @import("eval.zig").evaluate;
const uci = @import("uci.zig");

const MAX_PLY: usize = 200;
const INFINITY: i32 = 50000;
const CHECKMATE: i32 = 49000;
const R: i32 = 3; // reduction limit

var nodes: usize = 0;

fn negamax(board: *Board, alpha_: i32, beta_: i32, depth_: u8) i32 {
    @setEvalBranchQuota(5000000);
    var alpha = alpha_;
    var beta = beta_;
    var depth = depth_;

    // set to true if PV exist
    var found_pv: bool = false;

    pvLength[board.ply] = board.ply;

    // prune mate distance
    if (board.ply != 0) {
        alpha = @max(alpha, -CHECKMATE + @as(i32, @intCast(board.ply)));
        beta = @min(beta, CHECKMATE + @as(i32, @intCast(board.ply)) - 1);
    }
    if (alpha >= beta) return alpha;

    // use quiescense search at root node
    if (depth == 0) return quiescense(board, alpha, beta);

    // exceed ply limit
    if (board.ply >= MAX_PLY) return evaluate(board.*);

    nodes += 1;

    // increase depth if either king is in check
    var attacks_on_king: u64 = board.getAttackers(board.kingSqr(board.side), board.side ^ 1);
    if (attacks_on_king != 0) depth += 1;

    var list: MoveList = .{};
    genLegal(board, &list);
    sortMoves(board, &list);

    // no legal move on the board
    if (list.count == 0) {
        // checkmate
        if (attacks_on_king != 0) return -CHECKMATE + @as(i32, @intCast(board.ply));
        // stalemate
        return 0;
    }

    if (board.followPV) enablePvScoring(board, &list);

    for (0..list.count) |count| {
        const move = list.moves[count].move;
        const board_copy = board.*;
        // make move
        makeMove(board, move);

        // run search
        var score: i32 = undefined;
        if (!found_pv) {
            score = -negamax(board, -beta, -alpha, depth - 1);
        } else {
            score = -negamax(board, -alpha - 1, -alpha, depth - 1);
            if (score > alpha) // move fail soft
                score = -negamax(board, -beta, -alpha, depth - 1); // search again
        }
        // restore board
        board.* = board_copy;

        // move fail high
        if (score >= beta) {
            return beta;
        }
        if (score > alpha) {
            // update alpha when better move is found
            alpha = score;
            found_pv = true;

            // collect PV
            pvTable[board.ply][board.ply] = list.moves[count].move;
            for ((board.ply + 1)..pvLength[board.ply + 1]) |nextPly|
                pvTable[board.ply][nextPly] = pvTable[board.ply + 1][nextPly];
            pvLength[board.ply] = pvLength[board.ply + 1];
        }
    }
    // move fail low
    return alpha;
}

fn quiescense(board: *Board, alpha_: i32, beta_: i32) i32 {
    @setEvalBranchQuota(5000000);
    var alpha: i32 = alpha_;
    var beta: i32 = beta_;
    var evaluation = evaluate(board.*);
    // return immediately if node fail high
    if (evaluation >= beta) return beta;
    if (evaluation > alpha) {
        // better move is found
        alpha = evaluation;
    }

    nodes += 1;

    var list: MoveList = .{};
    genLegal(board, &list);
    sortMoves(board, &list);

    for (0..list.count) |count| {
        const board_copy = board.*;
        const move = list.moves[count].move;

        // TODO: create noisy movegen instead
        if (move.isQuiet()) continue;
        makeMove(board, move);

        var score: i32 = -quiescense(board, -beta, -alpha);

        board.* = board_copy;

        if (score >= beta) return beta;
        if (score > alpha) {
            alpha = score;
        }
    }

    return alpha;
}

// TODO: enhance sort algorithm
fn sortMoves(board: *Board, list: *MoveList) void {
    for (0..list.count) |count| {
        scoreMove(board, &list.moves[count]);
    }
    for (0..list.count) |current| {
        for (current..list.count + 1) |next| {
            const current_move = list.moves[current];
            const next_move = list.moves[next];
            // do in place sorting
            if (current_move.score < next_move.score) {
                list.moves[current] = next_move;
                list.moves[next] = current_move;
            }
        }
    }
}

inline fn scoreMove(board: *Board, move: *ScoredMove) void {
    if (board.scorePV) {
        if (@as(u20, @bitCast(pvTable[0][board.ply])) == @as(u20, @bitCast(move.move))) {
            board.scorePV = false;
            move.score = 20000;
            return;
        }
    }
}

fn enablePvScoring(board: *Board, moveList: *MoveList) void {
    board.followPV = false;
    for (0..moveList.count) |count| {
        if (@as(u20, @bitCast(pvTable[0][board.ply])) == @as(u20, @bitCast(moveList.moves[count].move))) {
            board.scorePV = true;
            board.followPV = true;
        }
    }
}

pub fn searchPos(board: *Board, depth: u8) !void {
    @memset(&pvLength, 0);
    @memset(&pvTable, undefined);
    var score: i32 = 0;
    var alpha: i32 = -INFINITY;
    var beta: i32 = INFINITY;
    nodes = 0;

    for (1..(depth + 1)) |currentDepth| {
        board.followPV = true;

        score = negamax(board, alpha, beta, depth);

        try stdout.print("info score cp {} depth {} nodes {} pv", .{ score, currentDepth, nodes });
        for (0..pvLength[0]) |count| {
            try stdout.print(" {s}", .{uci.uciMove(pvTable[0][count])});
        }
        try stdout.print(" \n", .{});

        // narrow down the next search window
        alpha = score - 40;
        beta = score + 40;
    }
    try stdout.print("bestmove {s}\n", .{uci.uciMove(pvTable[0][0])});
}

var pvTable: [MAX_PLY][MAX_PLY]Move = undefined;
var pvLength: [MAX_PLY]usize = [_]usize{0} ** MAX_PLY;

var killer: [MAX_PLY][2]Move = undefined;
var moveScoreHistory: [6][64]i32 = undefined;
