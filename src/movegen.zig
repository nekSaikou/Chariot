const std = @import("std");
const abs = std.math.absCast;
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const MoveType = @import("types.zig").MoveType;
const Square = @import("types.zig").Square;
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;

pub fn genLegal(board: *Board, list: *MoveList) void {
    genThreatMask(board, board.side, board.kingSqr(board.side));
    genKingMoves(board, list);
    // only generate king moves during double check
    if (board.checks == 2) return;
    genPawnMoves(board, list);
    genKnightMoves(board, list);
    genBishopMoves(board, list);
    genRookMoves(board, list);
    genQueenMoves(board, list);
}

fn genQueenMoves(board: *Board, list: *MoveList) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    var bitboard: u64 = board.pieceBB(4, side);
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks = atk.getQueenAttacks(src, board.allPieces()) & ~board.occupancy[side];
        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);
            // only generate move along the pinned line if it exists
            if (getBit(board.pinDiag, src) != 0 and getBit(board.pinDiag, dest) == 0) continue;
            if (getBit(board.pinOrth, src) != 0 and getBit(board.pinOrth, dest) == 0) continue;
            if (getBit(board.checkMask, dest) != 0)
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .flag = if (getBit(board.occupancy[xside], dest) != 0) 4 else 0,
                    .piece = 4,
                    .color = side,
                }, list);
        }
    }
}

fn genRookMoves(board: *Board, list: *MoveList) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    var bitboard: u64 = board.pieceBB(3, side);
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        // rook can't move when pinned diagonally
        if (getBit(board.pinDiag, src) != 0) continue;

        var attacks = atk.getRookAttacks(src, board.allPieces()) & ~board.occupancy[side];
        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);
            // only generate move along the pinned line if it exists
            if (getBit(board.pinOrth, src) != 0 and getBit(board.pinOrth, dest) == 0) continue;
            if (getBit(board.checkMask, dest) != 0)
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .flag = if (getBit(board.occupancy[xside], dest) != 0) 4 else 0,
                    .piece = 3,
                    .color = side,
                }, list);
        }
    }
}

fn genBishopMoves(board: *Board, list: *MoveList) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    var bitboard: u64 = board.pieceBB(2, side);
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        // bishop can't move when pinned orthogonally
        if (getBit(board.pinOrth, src) != 0) continue;

        var attacks = atk.getBishopAttacks(src, board.allPieces()) & ~board.occupancy[side];
        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);
            // only generate move along the pinned diagonal if it exists
            if (getBit(board.pinDiag, src) != 0 and getBit(board.pinDiag, dest) == 0) continue;
            if (getBit(board.checkMask, dest) != 0)
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .flag = if (getBit(board.occupancy[xside], dest) != 0) 4 else 0,
                    .piece = 2,
                    .color = side,
                }, list);
        }
    }
}

fn genKnightMoves(board: *Board, list: *MoveList) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    var bitboard: u64 = board.pieceBB(1, side);
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        // knight can't move at all when pinned
        if (getBit(board.pinDiag | board.pinOrth, src) != 0) continue;

        var attacks = atk.getKnightAttacks(src) & ~board.occupancy[side];
        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);
            if (getBit(board.checkMask, dest) != 0)
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .flag = if (getBit(board.occupancy[xside], dest) != 0) 4 else 0,
                    .piece = 1,
                    .color = side,
                }, list);
        }
    }
}

fn genKingMoves(board: *Board, list: *MoveList) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    // there's only one king so loop is unneeded
    const src: u6 = board.kingSqr(side);

    // temporarily pop occupancy bit for legality check
    popBit(&board.occupancy[side], src);
    // generate normal king moves
    var attacks = atk.getKingAttacks(src) & ~board.occupancy[side];
    while (attacks != 0) {
        const dest: u6 = @intCast(@ctz(attacks));
        popBit(&attacks, dest);
        // don't add if the move will expose the king to check
        if (board.getAttackers(dest, xside) != 0) continue;
        addMove(Move{
            .src = src,
            .dest = dest,
            .flag = if (getBit(board.occupancy[xside], dest) != 0) 4 else 0,
            .piece = 5,
            .color = side,
        }, list);
    }
    // set the removed bit back in place
    setBit(&board.occupancy[side], src);

    // generate castling moves
    switch (side) {
        0 => {
            if (board.castle & WK_CASTLE != 0 and
                getBit(board.allPieces(), @intFromEnum(Square.f1)) == 0 and
                getBit(board.allPieces(), @intFromEnum(Square.g1)) == 0 and
                board.getAttackers(@intFromEnum(Square.e1), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.f1), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.g1), xside) == 0)
            {
                addMove(Move{
                    .src = src,
                    .dest = @intFromEnum(Square.g1),
                    .flag = 2,
                    .piece = 5,
                    .color = side,
                }, list);
            }
            if (board.castle & WQ_CASTLE != 0 and
                getBit(board.allPieces(), @intFromEnum(Square.b1)) == 0 and
                getBit(board.allPieces(), @intFromEnum(Square.c1)) == 0 and
                getBit(board.allPieces(), @intFromEnum(Square.d1)) == 0 and
                board.getAttackers(@intFromEnum(Square.e1), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.d1), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.c1), xside) == 0)
            {
                addMove(Move{
                    .src = src,
                    .dest = @intFromEnum(Square.c1),
                    .flag = 3,
                    .piece = 5,
                    .color = side,
                }, list);
            }
        },
        1 => {
            if (board.castle & BK_CASTLE != 0 and
                getBit(board.allPieces(), @intFromEnum(Square.f8)) == 0 and
                getBit(board.allPieces(), @intFromEnum(Square.g8)) == 0 and
                board.getAttackers(@intFromEnum(Square.e8), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.f8), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.g8), xside) == 0)
            {
                addMove(Move{
                    .src = src,
                    .dest = @intFromEnum(Square.g8),
                    .flag = 2,
                    .piece = 5,
                    .color = side,
                }, list);
            }
            if (board.castle & BQ_CASTLE != 0 and
                getBit(board.allPieces(), @intFromEnum(Square.b8)) == 0 and
                getBit(board.allPieces(), @intFromEnum(Square.c8)) == 0 and
                getBit(board.allPieces(), @intFromEnum(Square.d8)) == 0 and
                board.getAttackers(@intFromEnum(Square.e8), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.d8), xside) == 0 and
                board.getAttackers(@intFromEnum(Square.c8), xside) == 0)
            {
                addMove(Move{
                    .src = src,
                    .dest = @intFromEnum(Square.c8),
                    .flag = 3,
                    .piece = 5,
                    .color = side,
                }, list);
            }
        },
    }
}

fn genPawnMoves(board: *Board, list: *MoveList) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    var bitboard: u64 = board.pieceBB(0, board.side);
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        const push = pawnPush(board.*, src, side);
        const doublePush = doublePawnPush(board.*, src, side);
        // when a pawn is pinned vertically, we can add the
        // available push along the pin and skip the rest
        // promotion is not a concern because
        // pawn can't move on 7th rank while being pinned
        if (getBit(board.pinOrth, src) != 0) {
            if (push != null and getBit(board.pinOrth, push.?) != 0 and
                getBit(board.checkMask, push.?) != 0)
                addMove(Move{
                    .src = src,
                    .dest = push.?,
                    .flag = 0,
                    .piece = 0,
                    .color = side,
                }, list);
            if (doublePush != null and getBit(board.pinOrth, doublePush.?) != 0 and
                getBit(board.checkMask, doublePush.?) != 0)
                addMove(Move{
                    .src = src,
                    .dest = doublePush.?,
                    .flag = 1,
                    .piece = 0,
                    .color = side,
                }, list);
            continue;
        }
        // consider captures first because
        // diagonal pin calculation fits here conveniently
        var attacks = atk.getPawnAttacks(src, side) &
            (board.occupancy[xside] |
            if (board.epSqr != null) (@as(u64, 1) << board.epSqr.?) else 0);

        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);
            // reiterate if capture is not on check mask
            if (getBit(board.checkMask, dest) == 0) continue;
            // when a pawn is pinned diagonally, we add the capture
            // along the pinned diagonal and the rest of the moves
            // can be safely skipped
            if (getBit(board.pinDiag, src) != 0) {
                if (getBit(board.pinDiag, dest) != 0) {
                    // check for promotion first
                    if (getBit(promotionRank[side], src) != 0) {
                        for (12..16) |promo| {
                            addMove(Move{
                                .src = src,
                                .dest = dest,
                                .flag = @intCast(promo),
                                .piece = 0,
                                .color = side,
                            }, list);
                        }
                    } else addMove(Move{
                        .src = src,
                        .dest = dest,
                        .flag = 4,
                        .piece = 0,
                        .color = side,
                    }, list);
                }
                continue;
            } else {
                if (getBit(promotionRank[side], src) != 0) {
                    for (12..16) |promo| {
                        addMove(Move{
                            .src = src,
                            .dest = dest,
                            .flag = @intCast(promo),
                            .piece = 0,
                            .color = side,
                        }, list);
                    }
                } else {
                    if (board.epSqr != null and dest == board.epSqr.?)
                        addMove(Move{
                            .src = src,
                            .dest = dest,
                            .flag = 5,
                            .piece = 0,
                            .color = side,
                        }, list)
                    else
                        addMove(Move{
                            .src = src,
                            .dest = dest,
                            .flag = 4,
                            .piece = 0,
                            .color = side,
                        }, list);
                }
            }
        }
        // can't push pawns while pinned diagonally
        if (getBit(board.pinDiag, src) == 0) {
            if (doublePush != null and
                getBit(board.checkMask, doublePush.?) != 0)
                addMove(Move{
                    .src = src,
                    .dest = doublePush.?,
                    .flag = 1,
                    .piece = 0,
                    .color = side,
                }, list);
            if (push != null and
                getBit(board.checkMask, push.?) != 0)
                if (getBit(promotionRank[side], src) != 0) {
                    for (8..12) |promo| {
                        addMove(Move{
                            .src = src,
                            .dest = push.?,
                            .flag = @intCast(promo),
                            .piece = 0,
                            .color = side,
                        }, list);
                    }
                } else addMove(Move{
                    .src = src,
                    .dest = push.?,
                    .flag = 0,
                    .piece = 0,
                    .color = side,
                }, list);
        }
    }
}

inline fn genThreatMask(board: *Board, color: u1, sqr: u6) void {
    const new_mask = genCheckMask(board, color, sqr);
    board.checkMask = if (new_mask != 0) new_mask else NOCHECK;
    genPinMask(board, color, sqr);
}

fn genCheckMask(board: *Board, color: u1, sqr: u6) u64 {
    var occupancy: u64 = board.allPieces();
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

fn genPinMask(board: *Board, color: u1, sqr: u6) void {
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

inline fn pawnPush(board: Board, src: u6, side: u1) ?u6 {
    const dest = switch (side) {
        0 => src - 8,
        1 => src + 8,
    };
    if (getBit(board.allPieces(), dest) != 0)
        return null; // push is blocked
    return dest;
}

inline fn doublePawnPush(board: Board, src: u6, side: u1) ?u6 {
    if (pawnPush(board, src, side) == null or
        getBit(firstRank[side], src) == 0)
        return null; //push is blocked at immediate rank
    const dest = switch (side) {
        0 => src - 16,
        1 => src + 16,
    };
    if (getBit(board.occupancy[0] | board.occupancy[1], dest) != 0)
        return null; // push is blocked
    return dest;
}

const promotionRank = [2]u64{ 0xff00, 0xff000000000000 };
const firstRank = [2]u64{ 0xff000000000000, 0xff00 };
const NOCHECK: u64 = 0xffffffffffffffff;
const WK_CASTLE: u4 = 1;
const WQ_CASTLE: u4 = 2;
const BK_CASTLE: u4 = 4;
const BQ_CASTLE: u4 = 8;
