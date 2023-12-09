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
const evaluate = @import("eval.zig").evaluate;
const uci = @import("uci.zig");
const TTable = @import("ttable.zig").TTable;
const Bound = @import("ttable.zig").Bound;

const MAX_PLY: usize = 200;
const INFINITY: i16 = 32000;
const CHECKMATE: i16 = 30000;
const NO_SCORE: i16 = -32700;

pub fn deepening(td: *ThreadData) void {
    var bestMove: Move = .{};
    var bestScore: i16 = -INFINITY;

    clearForSearch(td);

    for (1..td.searchInfo.depth + 1) |currDepth| {
        // enable follow PV
        td.searchData.followPV = true;
        bestScore = negamax(td, -INFINITY, INFINITY, @intCast(currDepth));

        // stop searching
        if (td.searchInfo.stop) break;

        // TODO: out of time

        writer.print("info score cp {} depth {} nodes {} time {} pv", .{
            bestScore,
            currDepth,
            td.searchInfo.nodes,
            td.timer.read() / std.time.ns_per_ms,
        }) catch unreachable;
        for (0..td.pvTable.length[0]) |count| {
            writer.print(" {s}", .{uci.uciMove(td.pvTable.moves[0][count])}) catch unreachable;
        }
        writer.print(" \n", .{}) catch unreachable;
        bestMove = td.pvTable.moves[0][0];
        buf.flush() catch unreachable;
    }
    writer.print("bestmove {s}\n", .{uci.uciMove(bestMove)}) catch unreachable;
    buf.flush() catch unreachable;
}

pub fn negamax(td: *ThreadData, alpha_: i16, beta_: i16, depth_: u8) i16 {
    @setEvalBranchQuota(5000000);
    var alpha = alpha_;
    var beta = beta_;
    var depth = depth_;
    var score: i16 = 0;
    var board: *Board = &td.board;
    var pvTable: *PVTable = &td.pvTable;

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
                return beta;
            }
            // better move is found, update alpha
            alpha = score; // collect PV
            foundPV = true;

            pvTable.moves[board.ply][board.ply] = list.moves[count].move;
            for ((board.ply + 1)..pvTable.length[board.ply + 1]) |nextPly|
                pvTable.moves[board.ply][nextPly] = pvTable.moves[board.ply + 1][nextPly];
            pvTable.length[board.ply] = pvTable.length[board.ply + 1];
        }
    }
    return alpha;
}

fn qsearch(td: *ThreadData, alpha_: i16, beta_: i16) i16 {
    @setEvalBranchQuota(5000000);
    var board: *Board = &td.board;
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
    for (0..list.count) |count| {
        scoreMove(td, &list.moves[count]);
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

fn scoreMove(td: *ThreadData, smove: *ScoredMove) void {
    var board: *Board = &td.board;
    if (td.searchData.scorePV)
        if (td.pvTable.moves[0][td.board.ply].getMoveKey() == smove.move.getMoveKey()) {
            td.searchData.scorePV = false;
            smove.score = 1 << 30;
            return;
        };

    if (smove.move.isCapture()) {
        smove.score += 1000000;
        for (0..6) |victim| {
            if (getBit(board.occupancy[board.side ^ 1] & board.pieces[victim], smove.move.dest) != 0) {
                smove.score += MVV_LVA[smove.move.piece][victim];
            }
        }
    } else {
        if (td.searchData.killer[0][board.ply].getMoveKey() == smove.move.getMoveKey()) {
            smove.score += 900000;
        }
        if (td.searchData.killer[1][board.ply].getMoveKey() == smove.move.getMoveKey()) {
            smove.score += 800000;
        }
        smove.score += td.searchData.history[board.side][smove.move.src][smove.move.dest];
    }
}

pub fn clearForSearch(td: *ThreadData) void {
    td.pvTable = PVTable{};
    td.searchInfo.nodes = 0;
    td.searchData = .{};

    td.board.ply = 0;
    td.timer = std.time.Timer.start() catch unreachable;
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
    if (td.searchInfo.timeset and (td.timer.read() / std.time.ns_per_ms) > td.searchInfo.timeLim)
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
