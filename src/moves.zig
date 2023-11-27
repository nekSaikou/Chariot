const std = @import("std");
const util = @import("util.zig");
const getBit = @import("util.zig").getBit;
const setBit = @import("util.zig").setBit;
const popBit = @import("util.zig").popBit;
const pieceBB = @import("util.zig").pieceBB;
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;

pub inline fn makeMove(board: *Board, move: Move, includeQuiet: bool) bool {
    if (!includeQuiet and move.capture == 0) return false;
    // copy board state for unmake
    const boardCopy: Board = board.*;

    // update board state
    popBit(&board.pieces[move.piece], move.src);
    setBit(&board.pieces[move.piece], move.dest);
    popBit(&board.occupancy[board.side], move.src);
    setBit(&board.occupancy[board.side], move.dest);
    board.epSqr = null;

    if (move.capture == 1) {
        for (0..6) |capturedPiece| {
            if (board.pieces[capturedPiece] & board.occupancy[board.side ^ 1] != 0) {
                popBit(&board.pieces[capturedPiece], move.dest);
                popBit(&board.occupancy[board.side ^ 1], move.dest);
                break;
            }
        }
    }

    if (move.promo != 0) {
        setBit(&board.pieces[move.promo], move.dest);
        popBit(&board.pieces[move.piece], move.dest);
    }

    const epCaptureSqr = switch (board.side) {
        0 => @addWithOverflow(move.dest, 8)[0],
        1 => @subWithOverflow(move.dest, 8)[0],
    };

    if (move.enpassant == 1) {
        popBit(&board.pieces[0], epCaptureSqr);
        popBit(&board.occupancy[board.side ^ 1], epCaptureSqr);
    }

    if (move.double == 1) board.epSqr = epCaptureSqr;

    if (move.castling == 1) {
        switch (move.dest) {
            62 => {
                popBit(&board.occupancy[0], 63);
                setBit(&board.occupancy[0], 61);
                popBit(&board.pieces[3], 63);
                setBit(&board.pieces[3], 61);
            },
            58 => {
                popBit(&board.occupancy[0], 56);
                setBit(&board.occupancy[0], 59);
                popBit(&board.pieces[3], 56);
                setBit(&board.pieces[3], 59);
            },
            6 => {
                popBit(&board.occupancy[1], 7);
                setBit(&board.occupancy[1], 5);
                popBit(&board.pieces[3], 7);
                setBit(&board.pieces[3], 5);
            },
            2 => {
                popBit(&board.occupancy[1], 0);
                setBit(&board.occupancy[1], 3);
                popBit(&board.pieces[3], 0);
                setBit(&board.pieces[3], 3);
            },
            else => unreachable,
        }
    }
    board.castlingRights &= updateCastlingRights[move.src];
    board.castlingRights &= updateCastlingRights[move.dest];

    board.side ^= 1;

    // return false if in check
    if (atk.getAttackers(board.*, board.kingSqr(board.side ^ 1), board.side) != 0) {
        board.* = boardCopy;
        return false;
    } else return true;
}

pub inline fn genPseudoLegal(board: Board, moveList: *MoveList) void {
    genPawnMoves(board, moveList);
    genKnightMoves(board, moveList);
    genBishopMoves(board, moveList);
    genRookMoves(board, moveList);
    genQueenMoves(board, moveList);
    genKingMoves(board, moveList);
}

inline fn genPawnMoves(board: Board, moveList: *MoveList) void {
    var bitboard: u64 = board.pieces[0] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks = atk.getPawnAttacks(src, board.side) & board.occupancy[board.side ^ 1];
        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);
            if (getBit(promotionRank[board.side], src) == 1) {
                // capture promotion
                for (1..5) |promo| {
                    moveList.moves[moveList.count] = Move{
                        .src = src,
                        .dest = dest,
                        .piece = 0,
                        .promo = @intCast(promo),
                        .capture = 1,
                    };
                    moveList.count += 1;
                }
            } else {
                // normal capture
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 0,
                    .capture = 1,
                };
                moveList.count += 1;
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

        if (getBit(board.occupancy[0] | board.occupancy[1], dest) == 0) {
            if (getBit(promotionRank[board.side], src) == 1) {
                // quiet promotion
                for (1..5) |promo| {
                    moveList.moves[moveList.count] = Move{
                        .src = src,
                        .dest = dest,
                        .piece = 0,
                        .promo = @intCast(promo),
                    };
                    moveList.count += 1;
                }
            } else {
                // normal push
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 0,
                };
                moveList.count += 1;
                // double push
                if (getBit(firstRank[board.side], src) == 1) {
                    const doubleDest = switch (board.side) {
                        0 => dest - 8,
                        1 => dest + 8,
                    };
                    if (getBit(board.occupancy[0] | board.occupancy[1], doubleDest) == 0) {
                        moveList.moves[moveList.count] = Move{
                            .src = src,
                            .dest = doubleDest,
                            .piece = 0,
                            .double = 1,
                        };
                        moveList.count += 1;
                    }
                }
            }
        }

        if (board.epSqr != null) {
            // enpassant capture
            var epAttacks: u64 = atk.getPawnAttacks(src, board.side) & (@as(u64, 1) << board.epSqr.?);
            if (epAttacks != 0) {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = @intCast(@ctz(epAttacks)),
                    .piece = 0,
                    .capture = 1,
                    .enpassant = 1,
                };
                moveList.count += 1;
            }
        }
    }
}

inline fn genKnightMoves(board: Board, moveList: *MoveList) void {
    var bitboard: u64 = board.pieces[1] & board.occupancy[board.side];
    while (bitboard != 0) {
        const src: u6 = @intCast(@ctz(bitboard));
        popBit(&bitboard, src);

        var attacks: u64 = atk.getKnightAttacks(src) & ~board.occupancy[board.side];

        while (attacks != 0) {
            const dest: u6 = @intCast(@ctz(attacks));
            popBit(&attacks, dest);

            if (getBit(board.occupancy[board.side ^ 1], dest) == 1) {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 1,
                    .capture = 1,
                };
                moveList.count += 1;
            } else {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 1,
                };
                moveList.count += 1;
            }
        }
    }
}

inline fn genBishopMoves(board: Board, moveList: *MoveList) void {
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
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 2,
                    .capture = 1,
                };
                moveList.count += 1;
            } else {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 2,
                };
                moveList.count += 1;
            }
        }
    }
}

inline fn genRookMoves(board: Board, moveList: *MoveList) void {
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
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 3,
                    .capture = 1,
                };
                moveList.count += 1;
            } else {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 3,
                };
                moveList.count += 1;
            }
        }
    }
}

inline fn genQueenMoves(board: Board, moveList: *MoveList) void {
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
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 4,
                    .capture = 1,
                };
                moveList.count += 1;
            } else {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 4,
                };
                moveList.count += 1;
            }
        }
    }
}

inline fn genKingMoves(board: Board, moveList: *MoveList) void {
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
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 5,
                    .capture = 1,
                };
                moveList.count += 1;
            } else {
                moveList.moves[moveList.count] = Move{
                    .src = src,
                    .dest = dest,
                    .piece = 5,
                };
                moveList.count += 1;
            }
        }
        //generate castling
        switch (board.side) {
            0 => {
                if (board.castlingRights & 0b0001 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 61) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 62) == 0 and
                    atk.getAttackers(board, 60, 1) == 0 and
                    atk.getAttackers(board, 61, 1) == 0)
                {
                    moveList.moves[moveList.count] = Move{
                        .src = 60, // e1
                        .dest = 62, // g1
                        .piece = 5,
                        .castling = 1,
                    };
                    moveList.count += 1;
                }
                if (board.castlingRights & 0b0010 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 59) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 58) == 0 and
                    atk.getAttackers(board, 60, 1) == 0 and
                    atk.getAttackers(board, 59, 1) == 0)
                {
                    moveList.moves[moveList.count] = Move{
                        .src = 60, // e1
                        .dest = 58, // c1
                        .piece = 5,
                        .castling = 1,
                    };
                    moveList.count += 1;
                }
            },
            1 => {
                if (board.castlingRights & 0b0100 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 5) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 6) == 0 and
                    atk.getAttackers(board, 4, 0) == 0 and
                    atk.getAttackers(board, 5, 0) == 0)
                {
                    moveList.moves[moveList.count] = Move{
                        .src = 4, // e8
                        .dest = 6, // g8
                        .piece = 5,
                        .castling = 1,
                    };
                    moveList.count += 1;
                }
                if (board.castlingRights & 0b1000 != 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 3) == 0 and
                    getBit(board.occupancy[0] | board.occupancy[1], 2) == 0 and
                    atk.getAttackers(board, 4, 0) == 0 and
                    atk.getAttackers(board, 3, 0) == 0)
                {
                    moveList.moves[moveList.count] = Move{
                        .src = 4, // e8
                        .dest = 2, // gc
                        .piece = 5,
                        .castling = 1,
                    };
                    moveList.count += 1;
                }
            },
        }
    }
}

const promotionRank = [2]u64{ 0xff00, 0xff000000000000 };
const firstRank = [2]u64{ 0xff000000000000, 0xff00 };

const updateCastlingRights: [64]u4 = .{
    // zig fmt: off
         7, 15, 15, 15,  3, 15, 15, 11,
        15, 15, 15, 15, 15, 15, 15, 15,
        15, 15, 15, 15, 15, 15, 15, 15,
        15, 15, 15, 15, 15, 15, 15, 15,
        15, 15, 15, 15, 15, 15, 15, 15,
        15, 15, 15, 15, 15, 15, 15, 15,
        15, 15, 15, 15, 15, 15, 15, 15,
        13, 15, 15, 15, 12, 15, 15, 14
    // zig fmt: on
};
