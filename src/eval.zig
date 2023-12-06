const std = @import("std");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const MoveType = @import("types.zig").MoveType;
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;

pub inline fn evaluate(board: Board) i16 {
    var score: i16 = 0;
    var bitboard: u64 = undefined;
    var sqr: u6 = undefined;

    for (0..2) |color| {
        for (0..6) |pc| {
            bitboard = board.pieces[pc] & board.occupancy[color];
            while (bitboard != 0) {
                sqr = @intCast(@ctz(bitboard));
                popBit(&bitboard, sqr);
                switch (color) {
                    0 => {
                        score += matValues[pc];
                        switch (pc) {
                            0 => score += pawnRelValues[sqr],
                            1 => score += knightRelValues[sqr],
                            2 => score += bishopRelValues[sqr],
                            3 => score += rookRelValues[sqr],
                            4 => score += queenRelValues[sqr],
                            5 => score += kingRelValues[sqr],
                            else => unreachable,
                        }
                    },
                    1 => {
                        score -= matValues[pc];
                        switch (pc) {
                            0 => score -= pawnRelValues[mirrorValues[sqr]],
                            1 => score -= knightRelValues[mirrorValues[sqr]],
                            2 => score -= bishopRelValues[mirrorValues[sqr]],
                            3 => score -= rookRelValues[mirrorValues[sqr]],
                            4 => score -= queenRelValues[mirrorValues[sqr]],
                            5 => score -= kingRelValues[mirrorValues[sqr]],
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                }
            }
        }
    }

    switch (board.side) {
        0 => return score,
        1 => return -score,
    }
}

const matValues = [6]i16{ 100, 345, 360, 525, 1000, 10000 };

const pawnRelValues = [64]i16{
    // zig fmt: off
    90,  90,  90,  90,  90,  90,  90,  90,
    50,  50,  50,  40,  40,  50,  50,  50,
    20,  20,  20,  30,  30,  30,  20,  20,
    10,  10,  10,  20,  20,  10,  10,  10,
     5,   5,  10,  20,  20,   5,   5,   5,
     0,   0,   0,   5,   5,   0,   0,   0,
     0,   0,   0, -10, -10,  10,   0,   0,
     0,   0,   0,   0,   0,   0,   0,   0
    // zig fmt: on
};

const knightRelValues = [64]i16{
    // zig fmt: off
   -30,   0,   0,   0,   0,   0,   0, -30,
    -5,   0,   0,  10,  10,   0,   0,  -5,
    -5,   5,  20,  20,  20,  20,   5,  -5,
    -5,  10,  20,  25,  25,  20,  10,  -5,
    -5,  10,  20,  30,  30,  20,  10,  -5,
    -5,   5,  15,  10,  10,  20,   5,  -5,
   -10,   0,   0,   0,   0,   0,   0, -10,
   -30, -10,   0,   0,   0,   0, -10, -30
    // zig fmt: on
};

const bishopRelValues = [64]i16{
    // zig fmt: off
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   0,  10,  10,   0,   0,   0,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,  10,   0,   0,   0,   0,  10,   0,
     0,  25,   0,   0,   0,   0,  25,   0,
     0,   0, -10,   0,   0, -10,   0,   0
    // zig fmt: on
};

const rookRelValues = [64]i16{
    // zig fmt: off
    40,  40,  40,  40,  40,  40,  40,  40,
    50,  50,  50,  50,  50,  50,  50,  50,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,   0,  10,  20,  20,  10,   0,   0,
     0,   0,   0,  20,  20,   0,   0,   0
    // zig fmt: on
};

const queenRelValues = [64]i16{
    // zig fmt: off
   -20,   0,   0,   0,   0,   0,   0, -20,
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   0,   0,   0,   0,   0,   0,
   -15, -10,   0,   0,   0,   0, -10, -15,
   -25, -15,   0,   0,   0,   0, -15, -25
    // zig fmt: on
};

const kingRelValues = [64]i16{
    // zig fmt: off
     0,   0,   0,   0,   0,   0,   0,   0,
     0,   0,   5,   5,   5,   5,   0,   0,
     0,   5,   5,  10,  10,   5,   5,   0,
     0,   5,  10,  15,  15,  10,   5,   0,
     0,   5,  10,  15,  15,  10,   5,   0,
     0,   0,   5,  10,  10,   5,   0,   0,
     0,   0,   0,  -5,  -5,   0,   0,   0,
     0,   5,   5,   0, -10,   0,  10,   0
    // zig fmt: on
};

const mirrorValues = [64]u6{
    // zig fmt: off
    56, 57, 58, 59, 60, 61, 62, 63,
    48, 49, 50, 51, 52, 53, 54, 55,
    40, 41, 42, 43, 44, 45, 46, 47,
    32, 33, 34, 35, 36, 37, 38, 39,
    24, 25, 26, 27, 28, 29, 30, 31,
    16, 17, 18, 19, 20, 21, 22, 23,
     8,  9, 10, 11, 12, 13, 14, 15,
     0,  1,  2,  3,  4,  5,  6,  7
    // zig fmt: on
};
