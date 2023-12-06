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
const tt = @import("ttable.zig");
const Bound = tt.Bound;

const MAX_PLY: usize = 200;
const INFINITY: i16 = 32000;
const CHECKMATE: i16 = 30000;
const NO_SCORE: i16 = -32700;
const R: i16 = 3; // reduction limit

var nodes: usize = 0;

fn negamax(board: *Board, alpha_: i16, beta_: i16, depth_: u8) i16 {
    @setEvalBranchQuota(5000000);
    var alpha = alpha_;
    var beta = beta_;
    var depth = depth_;

    const ttEntry = tt.table.data.items[tt.table.index(board.posKey)];

    var score: i16 = undefined;
    var best_move_key: u16 = 0; // used for ordering with TT

    if (tt.table.probeHashEntry(board.*)) {
        score = ttEntry.score;
        best_move_key = ttEntry.bestMove;
        // make sure the node is not PV and the TT entry is not worse
        if (alpha - beta == -1 and depth <= ttEntry.depth)
            return score;
    }

    // set to true if PV exist
    var found_pv: bool = false;

    pvLength[board.ply] = board.ply;

    if (board.hmc >= 100) return 0; // 50 moves rule

    // prune mate distance
    if (board.ply != 0) {
        alpha = @max(alpha, -CHECKMATE + @as(i16, @intCast(board.ply)));
        beta = @min(beta, CHECKMATE + @as(i16, @intCast(board.ply)) - 1);
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
        if (attacks_on_king != 0) return -CHECKMATE + @as(i16, @intCast(board.ply));
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
            if (move.isQuiet()) {
                killer[board.ply][1] = killer[board.ply][0];
                killer[board.ply][0] = move;
            }

            tt.table.storeHashEntry(board.posKey, move.getMoveKey(), score, NO_SCORE, depth, Bound.beta);

            return beta;
        }
        if (score > alpha) {
            // store history move
            if (move.isQuiet()) {
                history[move.src][move.dest] += @as(i16, depth) * @as(i16, depth);
            }

            // update best move key to be stored in TT at the end
            best_move_key = move.getMoveKey();

            // store as exact PV
            tt.table.storeHashEntry(board.posKey, move.getMoveKey(), score, NO_SCORE, depth, Bound.exact);

            // better move is found, update alpha
            alpha = score;
            found_pv = true;

            // collect PV
            pvTable[board.ply][board.ply] = list.moves[count].move;
            for ((board.ply + 1)..pvLength[board.ply + 1]) |nextPly|
                pvTable[board.ply][nextPly] = pvTable[board.ply + 1][nextPly];
            pvLength[board.ply] = pvLength[board.ply + 1];
        }
    }
    tt.table.storeHashEntry(board.posKey, best_move_key, score, NO_SCORE, depth, Bound.alpha);
    tt.table.ageUp();
    return alpha;
}

fn quiescense(board: *Board, alpha_: i16, beta_: i16) i16 {
    @setEvalBranchQuota(5000000);
    var alpha: i16 = alpha_;
    var beta: i16 = beta_;
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

        var score: i16 = -quiescense(board, -beta, -alpha);

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

fn scoreMove(board: *Board, smove: *ScoredMove) void {
    if (board.scorePV) {
        if (@as(u20, @bitCast(pvTable[0][board.ply])) == @as(u20, @bitCast(smove.move))) {
            board.scorePV = false;
            smove.score += 15000;
            return;
        }
    }

    if (smove.move.isCapture()) {
        for (0..6) |victim| {
            if (getBit(board.occupancy[board.side ^ 1] & board.pieces[victim], smove.move.dest) != 0) {
                smove.score = MVV_LVA[smove.move.piece][victim];
                return;
            }
        }
    } else {
        if (@as(u20, @bitCast(killer[board.ply][0])) == @as(u20, @bitCast(smove.move))) {
            smove.score += 6000;
            return;
        }
        if (@as(u20, @bitCast(killer[board.ply][1])) == @as(u20, @bitCast(smove.move))) {
            smove.score += 4000;
            return;
        }
        // return history score
        smove.score = history[smove.move.src][smove.move.dest];
        return;
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
    var score: i16 = 0;
    var alpha: i16 = -INFINITY;
    var beta: i16 = INFINITY;
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
var history = std.mem.zeroes([64][64]i16);

const MVV_LVA = [6][6]i16{
    [6]i16{ 105, 205, 305, 405, 505, 605 },
    [6]i16{ 104, 204, 304, 404, 504, 604 },
    [6]i16{ 103, 203, 303, 403, 503, 603 },
    [6]i16{ 102, 202, 302, 402, 502, 602 },
    [6]i16{ 101, 201, 301, 401, 501, 601 },
    [6]i16{ 100, 200, 300, 400, 500, 600 },
};
