const std = @import("std");
const stdout = std.io.getStdOut().writer();
var buf = std.io.bufferedWriter(stdout);
var writer = buf.writer();
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const ScoredMove = @import("types.zig").ScoredMove;
const MoveList = @import("types.zig").MoveList;
const MoveType = @import("types.zig").MoveType;
const PVTable = @import("types.zig").PVTable;
const ThreadData = @import("types.zig").ThreadData;
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;
const genLegal = @import("movegen.zig").genLegal;
const makeMove = @import("makemove.zig").makeMove;
const makeNullMove = @import("makemove.zig").makeNullMove;
const evaluate = @import("eval.zig").evaluate;
const uci = @import("uci.zig");
const TTable = @import("ttable.zig").TTable;
const Bound = @import("ttable.zig").Bound;

const MAX_PLY: usize = 200;
const INFINITY: i16 = 32000;
const CHECKMATE: i16 = 30000;
const NO_SCORE: i16 = -32700;
const R: u8 = 3;

pub fn deepening(td: *ThreadData) void {
    var bestMove: *Move = &td.bestMove;
    var bestScore: i16 = -INFINITY;

    clearForSearch(td);

    for (1..td.searchInfo.depth + 1) |currDepth| {
        // enable follow PV
        td.searchData.followPV = true;
        bestScore = negamax(td, -INFINITY, INFINITY, @intCast(currDepth));

        // stop searching
        if (td.searchInfo.stop) break;

        writer.print("info score cp {} depth {} nodes {} time {} pv", .{
            bestScore,
            currDepth,
            td.searchInfo.nodes,
            td.searchInfo.timer.read() / std.time.ns_per_ms,
        }) catch unreachable;
        for (0..td.pvTable.length[0]) |count| {
            writer.print(" {s}", .{uci.uciMove(td.pvTable.moves[0][count])}) catch unreachable;
        }
        writer.print(" \n", .{}) catch unreachable;
        bestMove.* = td.pvTable.moves[0][0];
        buf.flush() catch unreachable;
    }
    writer.print("bestmove {s}\n", .{uci.uciMove(bestMove.*)}) catch unreachable;
    buf.flush() catch unreachable;
}

pub fn negamax(td: *ThreadData, alpha_: i16, beta_: i16, depth_: u8) i16 {
    @setEvalBranchQuota(5000000);
    var alpha = alpha_;
    var beta = beta_;
    var depth = depth_;
    var score: i16 = -INFINITY;
    var board: *Board = td.board;
    var pvTable: *PVTable = &td.pvTable;

    const isPvNode: bool = alpha -% beta != -1;

    const ttEntry = td.ttable.data.items[td.ttable.index(board.posKey)];
    var best_move_key: u16 = 0; // stored in TT at the end
    var tt_hit: bool = false;

    // TT cutoff
    if (td.ttable.probeHashEntry(board)) {
        tt_hit = true;
        score = ttEntry.score;
        best_move_key = ttEntry.bestMove;
        // make sure the node is not PV and the TT entry is not worse
        if (!isPvNode and depth <= ttEntry.depth)
            switch (ttEntry.bound) {
                Bound.none => {},
                Bound.alpha => if (score <= alpha) return score,
                Bound.beta => if (score >= beta) return score,
                Bound.exact => return score,
            };
    }

    pvTable.length[board.ply] = @intCast(board.ply);
    // perform qsearch at root node
    if (depth == 0) return qsearch(td, alpha, beta);
    // fifty moves rule
    if (board.hmc >= 100) return 0;
    // max ply guard
    if (board.ply >= MAX_PLY) return evaluate(board);

    if (td.searchInfo.nodes & 2047 == 0) checkUp(td);
    td.searchInfo.nodes += 1;

    // prune mate distance
    if (td.board.ply != 0) {
        alpha = @max(alpha, -CHECKMATE + @as(i16, @intCast(board.ply)));
        beta = @min(beta, CHECKMATE + @as(i16, @intCast(board.ply)) - 1);
    }
    if (alpha >= beta) return alpha;

    // increase depth if either king is in check
    var attacks_on_king: u64 = board.getAttackers(board.kingSqr(board.side), board.side ^ 1);
    if (attacks_on_king != 0) depth += 1;

    var list: MoveList = .{};
    genLegal(board, &list);
    sortMoves(td, &list);

    // null move pruning
    // don't do this in the endgame to prevent falling for zugzwang
    if (!isPvNode and
        evaluate(board) >= beta and
        attacks_on_king == 0 and
        depth >= 4 and
        board.allPieces() != board.pieces[5] | board.pieces[0] and
        @popCount(board.allPieces()) > 5 and
        (!tt_hit or ttEntry.bound != Bound.beta or ttEntry.score >= beta))
    {
        const boardCopy = board.*;

        makeNullMove(board);
        var nmp_score: i16 = -negamax(td, -beta, -beta + 1, depth - 1 - R);

        board.* = boardCopy;

        if (nmp_score >= beta) return beta;
    }

    // no legal move on the board
    if (list.count == 0) {
        // checkmate
        if (attacks_on_king != 0) return -CHECKMATE + @as(i16, @intCast(board.ply));
        // stalemate
        return 0;
    }

    if (td.searchData.followPV) enablePVScoring(td, &list);
    // set to true after the first alpha raise
    var foundPV: bool = false;

    for (0..list.count) |count| {
        const move = list.moves[count].move;
        const board_copy = board.*;

        //if (!isPvNode and attacks_on_king == 0) {
        //    // late move pruning
        //    // if depth is low, skip moves with lower score
        //    if (depth <= 3 and count > depth * 10) break;
        //}

        // make move
        makeMove(board, move);

        // run search
        if (foundPV) {
            score = -negamax(td, -alpha - 1, -alpha, depth - 1);
            // PV node, perform full window search
            if (score > alpha)
                score = -negamax(td, -beta, -alpha, depth - 1);
        } else {
            score = -negamax(td, -beta, -alpha, depth - 1);
        }

        // restore board
        board.* = board_copy;

        // stop searching
        if (td.searchInfo.stop) return 0;

        if (score > alpha) {
            // move fail high
            if (score >= beta) {
                if (move.isQuiet()) {
                    td.searchData.killer[1][board.ply] = td.searchData.killer[0][board.ply];
                    td.searchData.killer[0][board.ply] = move;
                    td.searchData.history[board.side][move.src][move.dest] += depth * depth;
                }
                td.ttable.storeHashEntry(board.posKey, move.getMoveKey(), score, NO_SCORE, depth, Bound.beta);
                return beta;
            }
            // better move is found, update alpha
            alpha = score; // collect PV
            foundPV = true;

            // update best move key to be stored in TT
            best_move_key = move.getMoveKey();

            pvTable.moves[board.ply][board.ply] = list.moves[count].move;
            for ((board.ply + 1)..pvTable.length[board.ply + 1]) |nextPly|
                pvTable.moves[board.ply][nextPly] = pvTable.moves[board.ply + 1][nextPly];
            pvTable.length[board.ply] = pvTable.length[board.ply + 1];
        }
    }
    const bound = if (foundPV) Bound.exact else Bound.alpha;
    td.ttable.storeHashEntry(board.posKey, best_move_key, score, NO_SCORE, depth, bound);
    return alpha;
}

fn qsearch(td: *ThreadData, alpha_: i16, beta_: i16) i16 {
    @setEvalBranchQuota(5000000);
    var board: *Board = td.board;
    var alpha: i16 = alpha_;
    var beta: i16 = beta_;
    var evaluation = evaluate(board);
    // return immediately if node fail high
    if (evaluation >= beta) return beta;
    if (evaluation > alpha) {
        alpha = evaluation;
    }

    // check if time ran out
    if (td.searchInfo.nodes & 2047 == 0) checkUp(td);
    td.searchInfo.nodes += 1;

    var list: MoveList = .{};
    genLegal(board, &list);
    sortMoves(td, &list);

    for (0..list.count) |count| {
        const board_copy = board.*;
        const move = list.moves[count].move;

        // TODO: create noisy movegen instead
        if (move.isQuiet()) continue;
        makeMove(board, move);

        var score: i16 = -qsearch(td, -beta, -alpha);

        // restore board
        board.* = board_copy;

        // stop searching
        if (td.searchInfo.stop) return 0;

        if (score >= beta) return beta;
        if (score > alpha) {
            alpha = score;
        }
    }

    return alpha;
}

fn sortMoves(td: *ThreadData, list: *MoveList) void {
    scoreMove(td, list);
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

fn scoreMove(td: *ThreadData, list: *MoveList) void {
    var board: *Board = td.board;
    for (0..list.count) |count| {
        var smove: *ScoredMove = &list.moves[count];
        // is TT move
        if (smove.move.getMoveKey() == td.ttable.data.items[td.ttable.index(board.posKey)].bestMove)
            smove.score += 15000000;
        // is PV move, give the highest bonus
        if (td.searchData.scorePV)
            if (td.pvTable.moves[0][td.board.ply].getMoveKey() == smove.move.getMoveKey()) {
                td.searchData.scorePV = false;
                smove.score = 1 << 30;
                return;
            };

        if (smove.move.isCapture()) {
            smove.score += 10000000;
            for (0..6) |victim| {
                if (getBit(board.occupancy[board.side ^ 1] & board.pieces[victim], smove.move.dest) != 0) {
                    smove.score += MVV_LVA[smove.move.piece][victim];
                }
            }
        } else {
            if (td.searchData.killer[0][board.ply].getMoveKey() == smove.move.getMoveKey()) {
                smove.score += 9000000;
            } else if (td.searchData.killer[1][board.ply].getMoveKey() == smove.move.getMoveKey()) {
                smove.score += 8000000;
            }
            smove.score += td.searchData.history[board.side][smove.move.src][smove.move.dest];
        }
    }
}

pub fn clearForSearch(td: *ThreadData) void {
    td.searchInfo.timer.reset();
    td.pvTable = PVTable{};
    td.searchInfo.nodes = 0;
    td.searchData = .{};
    td.ttable.ageUp();

    td.board.ply = 0;
    td.searchInfo.timer = std.time.Timer.start() catch unreachable;
}

fn enablePVScoring(td: *ThreadData, list: *MoveList) void {
    td.searchData.followPV = false;
    for (0..list.count) |count|
        if (td.pvTable.moves[0][td.board.ply].getMoveKey() == list.moves[count].move.getMoveKey()) {
            td.searchData.followPV = true;
            td.searchData.scorePV = true;
        };
}

pub fn checkUp(td: *ThreadData) void {
    if (td.searchInfo.timeset and (td.searchInfo.timer.read() / std.time.ns_per_ms) > td.searchInfo.timeLim)
        td.searchInfo.stop = true;
}

const MVV_LVA = [6][6]i32{
    [6]i32{ 105, 205, 305, 405, 505, 605 },
    [6]i32{ 104, 204, 304, 404, 504, 604 },
    [6]i32{ 103, 203, 303, 403, 503, 603 },
    [6]i32{ 102, 202, 302, 402, 502, 602 },
    [6]i32{ 101, 201, 301, 401, 501, 601 },
    [6]i32{ 100, 200, 300, 400, 500, 600 },
};
