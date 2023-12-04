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

inline fn movePiece(board: *Board, src: u6, dest: u6, piece: u3, color: u1) void {
    clearPiece(board, src, piece, color);
    addPiece(board, dest, piece, color);
}

inline fn addPiece(board: *Board, sqr: u6, piece: u3, color: u1) void {
    setBit(board.pieces[piece], sqr);
    setBit(board.occupancy[color], sqr);
}

inline fn clearPiece(board: *Board, sqr: u6, piece: u3, color: u1) void {
    popBit(board.pieces[piece], sqr);
    popBit(board.occupancy[color], sqr);
}

inline fn updateCastlingRights(board: *Board, src: u6, dest: u6) void {
    board.castle &= castlingUpdate[src];
    board.castle &= castlingUpdate[dest];
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
