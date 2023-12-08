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
const TTable = @import("ttable.zig").TTable;
const Bound = @import("ttable.zig").Bound;

const MAX_PLY: usize = 200;
const INFINITY: i16 = 32000;
const CHECKMATE: i16 = 30000;
const NO_SCORE: i16 = -32700;

const MVV_LVA = [6][6]u32{
    [6]u32{ 105, 205, 305, 405, 505, 605 },
    [6]u32{ 104, 204, 304, 404, 504, 604 },
    [6]u32{ 103, 203, 303, 403, 503, 603 },
    [6]u32{ 102, 202, 302, 402, 502, 602 },
    [6]u32{ 101, 201, 301, 401, 501, 601 },
    [6]u32{ 100, 200, 300, 400, 500, 600 },
};
