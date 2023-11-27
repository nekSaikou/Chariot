const std = @import("std");
const util = @import("util.zig");
const getBit = @import("util.zig").getBit;
const setBit = @import("util.zig").setBit;
const popBit = @import("util.zig").popBit;
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const moves = @import("moves.zig");
const perftTest = @import("perft.zig").perftTest;

pub fn main() !void {
    atk.initAll();
    var board: Board = undefined;
    try board.parseFEN("r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1 ");

    try perftTest(&board, 4);

    //var board2: Board = undefined;
    //try board2.parseFEN("rnbqkbnr/p1pppppp/8/1p6/Q7/2P5/PP1PPPPP/RNB1KBNR b KQkq - 1 2");
    //_ = moves.makeMove(&board2, Move{
    //    .src = 25,
    //    .dest = 32,
    //    .piece = 0,
    //    .capture = 1,
    //}, true);

    //std.debug.print("game state 1\n  side: {any}\n  castle: {b}\n  epSqr: {any}\n", .{ board.side, board.castlingRights, board.epSqr });
    //std.debug.print("game state 2\n  side: {any}\n  castle: {b}\n  epSqr: {any}\n\n", .{ board2.side, board2.castlingRights, board2.epSqr });
    //std.debug.print("occupancy 1: 0x{x}\n           : {x}\n", .{ board.occupancy[0], board.occupancy[1] });
    //std.debug.print("occupancy 2: 0x{x}\n           : {x}\n\n", .{ board2.occupancy[0], board2.occupancy[1] });
    //std.debug.print("pawns 1: 0x{x}\n", .{board.pieces[0]});
    //std.debug.print("pawns 2: 0x{x}\n\n", .{board2.pieces[0]});
    //std.debug.print("knights 1: 0x{x}\n", .{board.pieces[1]});
    //std.debug.print("knights 2: 0x{x}\n\n", .{board2.pieces[1]});
    //std.debug.print("bishops 1: 0x{x}\n", .{board.pieces[2]});
    //std.debug.print("bishops 2: 0x{x}\n\n", .{board2.pieces[2]});
    //std.debug.print("rooks 1: 0x{x}\n", .{board.pieces[3]});
    //std.debug.print("rooks 2: 0x{x}\n\n", .{board2.pieces[3]});
    //std.debug.print("queens 1: 0x{x}\n", .{board.pieces[4]});
    //std.debug.print("queens 2: 0x{x}\n\n", .{board2.pieces[4]});
    //std.debug.print("kings 1: 0x{x}\n", .{board.pieces[5]});
    //std.debug.print("kings 2: 0x{x}\n\n", .{board2.pieces[5]});

    //try perftTest(&board, 1);
    //try perftTest(&board2, 1);
}
