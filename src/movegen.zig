const std = @import("std");
const abs = std.math.absCast;
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const MoveType = @import("types.zig").MoveType;
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;

inline fn isLegal(board: *Board, move: Move) bool {
    _ = move;
    _ = board;
}

pub inline fn genThreatMask(board: *Board, color: u1, sqr: u6) void {
    const new_mask = genCheckMask(board, color, sqr);
    board.checkMask = if (new_mask != 0) new_mask else NOCHECK;
    genPinMask(board, color, sqr);
}

inline fn genCheckMask(board: *Board, color: u1, sqr: u6) u64 {
    var occupancy: u64 = board.occupancy[0] | board.occupancy[1];
    var checks: u64 = 0;
    var pawn_mask: u64 = board.pieceBB(0, color ^ 1) & atk.getPawnAttacks(sqr, color);
    var knight_mask: u64 = board.pieceBB(1, color ^ 1) & atk.getKnightAttacks(sqr);
    var bishop_mask: u64 = (board.pieceBB(2, color ^ 1) |
        board.pieceBB(4, color ^ 1)) &
        atk.getBishopAttacks(sqr, occupancy) &
        ~board.occupancy[color];
    var rook_mask: u64 = (board.pieceBB(3, color ^ 1) |
        board.pieceBB(4, color ^ 1)) &
        atk.getRookAttacks(sqr, occupancy) &
        ~board.occupancy[color];
    board.checks = 0;

    if (pawn_mask != 0) {
        checks |= pawn_mask;
        board.checks += 1;
    }
    if (knight_mask != 0) {
        checks |= knight_mask;
        board.checks += 1;
    }
    if (bishop_mask != 0) {
        if (@popCount(bishop_mask) > 1) board.checks += 1;
        checks |= atk.betweenSqr[sqr][@ctz(bishop_mask)] | (@as(u64, 1) << @intCast(@ctz(bishop_mask)));
        board.checks += 1;
    }
    if (rook_mask != 0) {
        if (@popCount(rook_mask) > 1) board.checks += 1;
        checks |= atk.betweenSqr[sqr][@ctz(rook_mask)] | (@as(u64, 1) << @intCast(@ctz(rook_mask)));
        board.checks += 1;
    }
    return checks;
}

inline fn genPinMask(board: *Board, color: u1, sqr: u6) void {
    var opp_bb: u64 = board.occupancy[color ^ 1];
    var diag_mask: u64 = atk.getBishopAttacks(sqr, opp_bb) &
        (board.pieceBB(2, color ^ 1) |
        board.pieceBB(4, color ^ 1));
    var orth_mask: u64 = atk.getRookAttacks(sqr, opp_bb) &
        (board.pieceBB(3, color ^ 1) |
        board.pieceBB(4, color ^ 1));
    var diag_pin: u64 = 0;
    var orth_pin: u64 = 0;
    board.pinDiag = 0;
    board.pinOrth = 0;

    while (diag_mask != 0) {
        const index = @as(u6, @intCast(@ctz(diag_mask)));
        var possible_pin = atk.betweenSqr[sqr][index] | (@as(u64, 1) << index);
        if (@popCount(possible_pin & board.occupancy[color]) == 1)
            diag_pin |= possible_pin;
        popBit(&diag_mask, index);
    }
    while (orth_mask != 0) {
        const index = @as(u6, @intCast(@ctz(orth_mask)));
        var possible_pin = atk.betweenSqr[sqr][index] | (@as(u64, 1) << index);
        if (@popCount(possible_pin & board.occupancy[color]) == 1)
            orth_pin |= possible_pin;
        popBit(&orth_mask, index);
    }
    board.pinDiag = diag_pin;
    board.pinOrth = orth_pin;
}

inline fn addMove(move: Move, list: *MoveList) void {
    list.moves[list.count].move = move;
    list.moves[list.count].score = 0;
    list.count += 1;
}

const promotionRank = [2]u64{ 0xff00, 0xff000000000000 };
const firstRank = [2]u64{ 0xff000000000000, 0xff00 };
const NOCHECK = 0xffffffffffffffff;
