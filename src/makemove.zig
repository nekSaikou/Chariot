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
const genLegal = @import("movegen.zig").genLegal;
const zobrist = @import("zobrist.zig");

pub fn makeMove(board: *Board, move: Move) void {
    const side: u1 = board.side;
    const xside: u1 = board.side ^ 1;
    const src: u6 = move.src;
    const dest: u6 = move.dest;
    const piece: u3 = move.piece;
    const promo_type: u3 = move.getPromoType();
    const target_piece: u3 = board.targetPiece(dest);

    board.hmc += 1;
    const epCaptureSqr = switch (board.side) {
        0 => @addWithOverflow(move.dest, 8)[0],
        1 => @subWithOverflow(move.dest, 8)[0],
    };

    // reset half move clock when a pawn moves or a capture happens
    if (piece == 0) board.hmc = 0;

    if (move.isEnPassant()) {
        clearPiece(board, epCaptureSqr, 0, xside);
        board.hmc = 0;
    } else if (move.isCapture()) {
        clearPiece(board, dest, target_piece, xside);
        board.hmc = 0;
    }

    // update game state
    board.ply += 1;
    // xor out the epSqr
    if (board.epSqr != null) hashKey(board, zobrist.EnPassantKeys[board.epSqr.?]);
    board.epSqr = null;
    // move the piece
    clearPiece(board, src, piece, side);
    addPiece(board, dest, if (move.isPromo()) promo_type else piece, side);
    // add en passant square
    if (move.isDoublePush()) {
        board.epSqr = epCaptureSqr;
        hashKey(board, zobrist.EnPassantKeys[board.epSqr.?]);
    }

    if (move.isCastle()) switch (dest) {
        @intFromEnum(Square.g1) => movePiece(board, 63, 61, 3, 0),
        @intFromEnum(Square.c1) => movePiece(board, 56, 59, 3, 0),
        @intFromEnum(Square.g8) => movePiece(board, 7, 5, 3, 1),
        @intFromEnum(Square.c8) => movePiece(board, 0, 3, 3, 1),
        else => unreachable,
    };
    updateCastlingRights(board, src, dest);

    board.side ^= 1;
    // xor the new side key
    hashKey(board, zobrist.SideKey);
}

pub fn makeNullMove(board: *Board) void {
    // simply pass a turn
    board.ply += 1;
    board.side ^= 1;
    hashKey(board, zobrist.SideKey);
    if (board.epSqr != null)
        hashKey(board, zobrist.EnPassantKeys[board.epSqr.?]);
    board.epSqr = null;
}

inline fn movePiece(board: *Board, src: u6, dest: u6, piece: u3, color: u1) void {
    clearPiece(board, src, piece, color);
    addPiece(board, dest, piece, color);
}

inline fn addPiece(board: *Board, sqr: u6, piece: u3, color: u1) void {
    hashKey(board, zobrist.PieceKeys[piece][sqr]);
    hashKey(board, zobrist.OccupancyKeys[color][sqr]);
    setBit(&board.pieces[piece], sqr);
    setBit(&board.occupancy[color], sqr);
}

inline fn clearPiece(board: *Board, sqr: u6, piece: u3, color: u1) void {
    hashKey(board, zobrist.PieceKeys[piece][sqr]);
    hashKey(board, zobrist.OccupancyKeys[color][sqr]);
    popBit(&board.pieces[piece], sqr);
    popBit(&board.occupancy[color], sqr);
}

inline fn updateCastlingRights(board: *Board, src: u6, dest: u6) void {
    hashKey(board, zobrist.CastleKeys[board.castle]);

    board.castle &= castlingUpdate[src];
    board.castle &= castlingUpdate[dest];

    hashKey(board, zobrist.CastleKeys[board.castle]);
}

inline fn hashKey(board: *Board, key: u64) void {
    board.posKey ^= key;
}

const castlingUpdate: [64]u4 = .{
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
