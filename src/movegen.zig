const std = @import("std");
const abs = std.math.absCast;
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;
const atk = @import("attacks.zig");
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const Board = @import("types.zig").Board;
const Square = @import("types.zig").Square;

pub inline fn genPseudoLegal(board: Board, list: *MoveList) void {
    genPawnMove(board, list);
    genKnightMoves(board, list);
    genBishopMoves(board, list);
    genRookMoves(board, list);
    genQueenMoves(board, list);
    genKingMoves(board, list);
}

inline fn genPawnMove(board: Board, list: *MoveList) void {
    var bitboard: u64 = board.pieces[0] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks = atk.getPawnAttacks(src, board.side) & board.occupancy[board.side ^ 1];
        while (attacks != 0) {
            // handle capture
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(promotionRank[board.side], src) == 1) {
                // capture with promotion
                for (0..2) |specA| {
                    for (0..2) |specB| {
                        addMove(Move{
                            .src = src,
                            .dest = dest,
                            .capture = 1,
                            .promo = 1,
                            .specA = @intCast(specA),
                            .specB = @intCast(specB),
                        }, list, 0);
                    }
                }
            } else {
                // normal capture
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .capture = 1,
                }, list, 0);
            }
        }

        // generate quiet pawn moves
        const ds = switch (board.side) {
            0 => @subWithOverflow(src, 8),
            1 => @addWithOverflow(src, 8),
        };
        // skip if overflow
        if (ds[1] == 1) continue;
        const dest = ds[0];
        if (getBit(promotionRank[board.side], src) == 1) {
            // quiet promotion
            for (0..2) |specA| {
                for (0..2) |specB| {
                    addMove(Move{
                        .src = src,
                        .dest = dest,
                        .promo = 1,
                        .specA = @intCast(specA),
                        .specB = @intCast(specB),
                    }, list, 0);
                }
            }
        } else {
            // normal push
            addMove(Move{
                .src = src,
                .dest = dest,
            }, list, 0);

            // set destination for double push
            if (getBit(firstRank[board.side], src) == 1) {
                const doubleDest = switch (board.side) {
                    0 => dest - 8,
                    1 => dest + 8,
                };
                if (getBit(board.occupancy[0] | board.occupancy[1], doubleDest) == 0) {
                    addMove(Move{
                        .src = src,
                        .dest = doubleDest,
                        .specB = 1,
                    }, list, 0);
                }
            }
        }

        if (board.epSqr != null) {
            // enpassant capture
            var epAttacks: u64 = atk.getPawnAttacks(src, board.side) & (@as(u64, 1) << board.epSqr.?);
            if (epAttacks != 0) {
                addMove(Move{
                    .src = src,
                    .dest = @intCast(@ctz(epAttacks)),
                    .capture = 1,
                    .specB = 1,
                }, list, 0);
            }
        }
    }
}

inline fn genKnightMoves(board: Board, list: *MoveList) void {
    var bitboard: u64 = board.pieces[1] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks: u64 = atk.getKnightAttacks(src) & ~board.occupancy[board.side];

        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(board.occupancy[board.side ^ 1], dest) == 1) {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .capture = 1,
                }, list, 1);
            } else {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                }, list, 1);
            }
        }
    }
}

inline fn genBishopMoves(board: Board, list: *MoveList) void {
    var bitboard: u64 = board.pieces[2] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks: u64 =
            atk.getBishopAttacks(src, board.occupancy[0] | board.occupancy[1]) & ~board.occupancy[board.side];

        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(board.occupancy[board.side ^ 1], dest) != 0) {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .capture = 1,
                }, list, 2);
            } else {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                }, list, 2);
            }
        }
    }
}

inline fn genRookMoves(board: Board, list: *MoveList) void {
    var bitboard: u64 = board.pieces[3] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks: u64 =
            atk.getRookAttacks(src, board.occupancy[0] | board.occupancy[1]) & ~board.occupancy[board.side];

        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(board.occupancy[board.side ^ 1], dest) != 0) {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .capture = 1,
                }, list, 3);
            } else {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                }, list, 3);
            }
        }
    }
}

inline fn genQueenMoves(board: Board, list: *MoveList) void {
    var bitboard: u64 = board.pieces[4] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks: u64 =
            atk.getQueenAttacks(src, board.occupancy[0] | board.occupancy[1]) & ~board.occupancy[board.side];

        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(board.occupancy[board.side ^ 1], dest) != 0) {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .capture = 1,
                }, list, 4);
            } else {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                }, list, 4);
            }
        }
    }
}

inline fn genKingMoves(board: Board, list: *MoveList) void {
    var bitboard: u64 = board.pieces[5] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        // generate normal king moves
        var attacks: u64 = atk.getKingAttacks(src) & ~board.occupancy[board.side];
        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(board.occupancy[board.side ^ 1], dest) == 1) {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                    .capture = 1,
                }, list, 5);
            } else {
                addMove(Move{
                    .src = src,
                    .dest = dest,
                }, list, 5);
            }
        }
        //generate castling
        switch (board.side) {
            0 => {
                if (board.castlingRights & 0b0001 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 61) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 62) == 0 and
                    board.getAttackers(60, 1) == 0 and
                    board.getAttackers(61, 1) == 0)
                {
                    addMove(Move{
                        .src = 60,
                        .dest = 62,
                        .capture = 1,
                        .specA = 1,
                    }, list, 5);
                }
                if (board.castlingRights & 0b0010 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 59) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 58) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 57) == 0 and
                    board.getAttackers(60, 1) == 0 and
                    board.getAttackers(59, 1) == 0)
                {
                    addMove(Move{
                        .src = 60,
                        .dest = 58,
                        .capture = 1,
                        .specA = 1,
                        .specB = 1,
                    }, list, 5);
                }
            },
            1 => {
                if (board.castlingRights & 0b0100 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 5) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 6) == 0 and
                    board.getAttackers(4, 0) == 0 and
                    board.getAttackers(5, 0) == 0)
                {
                    addMove(Move{
                        .src = 4,
                        .dest = 6,
                        .capture = 1,
                        .specA = 1,
                    }, list, 5);
                }
                if (board.castlingRights & 0b1000 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 3) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 2) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 1) == 0 and
                    board.getAttackers(4, 0) == 0 and
                    board.getAttackers(3, 0) == 0)
                {
                    addMove(Move{
                        .src = 4,
                        .dest = 2,
                        .capture = 1,
                        .specA = 1,
                        .specB = 1,
                    }, list, 5);
                }
            },
        }
    }
}

// add a move to the list
inline fn addMove(move: Move, list: *MoveList, piece: u3) void {
    list.moves[list.count].move = move;
    list.moves[list.count].piece = piece;
    list.moves[list.count].score = 0;
    list.count += 1;
}

const promotionRank = [2]u64{ 0xff00, 0xff000000000000 };
const firstRank = [2]u64{ 0xff000000000000, 0xff00 };
