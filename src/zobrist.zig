const std = @import("std");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;

pub var PieceKeys = std.mem.zeroes([6][64]u64);
pub var OccupancyKeys = std.mem.zeroes([2][64]u64);
pub var EnPassantKeys = std.mem.zeroes([64]u64);
pub var CastleKeys = std.mem.zeroes([16]u64);
pub var SideKey: u64 = 0;

pub fn initRandomKeys() void {
    var seed = Random.new(557755);
    for (0..64) |sqr| {
        for (0..6) |pc| {
            PieceKeys[pc][sqr] = seed.rand();
        }
        for (0..2) |occ| {
            OccupancyKeys[occ][sqr] = seed.rand();
        }
        EnPassantKeys[sqr] = seed.rand();
    }
    for (0..16) |flag| {
        CastleKeys[flag] = seed.rand();
    }
    SideKey = seed.rand();
}

pub fn genPosKey(board: Board) u64 {
    var key: u64 = 0;

    for (0..64) |sqr| {
        const piece: u3 = board.targetPiece(@intCast(sqr));
        if (piece != 6) {
            key ^= PieceKeys[piece][sqr];
            key ^= OccupancyKeys[board.getOccupancy(@intCast(sqr)).?][sqr];
        }
    }

    if (board.epSqr != null) key ^= EnPassantKeys[board.epSqr.?];
    key ^= CastleKeys[board.castle];
    if (board.side != 0) key ^= SideKey;

    return key;
}

// This piece of code is taken from another open source chess engine, Avalanche.
const Random = struct {
    seed: u128,

    pub fn rand(self: *@This()) u64 {
        var x = self.seed;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.seed = x;
        var r = @as(u64, @truncate(x));
        r = r ^ @as(u64, @truncate(x >> 64));
        return r;
    }

    pub fn new(seed: u128) Random {
        return Random{ .seed = seed };
    }
};
