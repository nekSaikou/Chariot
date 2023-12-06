const std = @import("std");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const zobrist = @import("zobrist.zig");

const MB: usize = 1048576;
const KB: usize = 1024;

pub var table: TTable = .{};

pub const HashEntry = packed struct(u128) {
    bestMove: u16 = 0,
    score: i16 = 0, // score from search
    eval: i16 = 0, // static eval
    hashKey: u64 = 0,
    bound: u2 = 0, // what caused the cutoff
    depth: u8 = 0,
    age: u6 = 0,
    // bound:
    // 0 none
    // 1 alpha
    // 2 beta
    // 3 exact pv
};

const HashTable = std.ArrayList(HashEntry);

var Arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);

pub const TTable = struct {
    data: HashTable = HashTable.init(Arena.allocator()),
    size: usize = 16 * MB / @sizeOf(HashEntry),
    age: u6 = 0,

    pub inline fn clear(self: *@This()) void {
        for (self.data.items) |*ptr| {
            ptr.* = 0;
        }
    }

    pub inline fn storeHashEntry(
        self: *@This(),
        board: Board,
        move_: Move,
        score: i16,
        eval: i16,
        bound: u2,
        depth: u8,
    ) void {
        const move = move_.getMoveKey();
        const tt_index = self.index(board.posKey);
        var prevEntry: *HashEntry = &self.data.items[tt_index];

        // replace less valuable entry
        if (bound == 3 or // new entry is exact PV
            prevEntry.age != self.age or // previous entry is older
            prevEntry.hashKey != board.posKey or // from different positions
            depth + 4 + bound > prevEntry.depth // previous entry has lower depth
        ) {
            prevEntry.hashKey = board.posKey;
            prevEntry.bestMove = move;
            prevEntry.score = score;
            prevEntry.eval = eval;
            prevEntry.bound = bound;
            prevEntry.depth = depth;
            prevEntry.age = self.age;
        }
    }

    pub inline fn probeHashEntry(self: *@This(), board: Board) bool {
        const tt_index: u64 = self.index(board.posKey);
        const entry: HashEntry = self.data.items[tt_index];

        return entry.hashKey == board.posKey;
    }

    pub inline fn ageUp(self: *@This()) void {
        self.age +%= 1;
    }

    pub inline fn prefetch(self: *@This(), board: Board) void {
        @prefetch(&self.data.items[self.index(board.posKey)], .{
            .rw = .read,
            .locality = 2,
            .cache = .data,
        });
    }

    pub inline fn index(self: *@This(), hash: u64) u64 {
        return @as(u64, @intCast(@as(u128, @intCast(hash)) * @as(u128, @intCast(self.size)) >> 64));
    }
};

pub fn initTT(size: usize) void {
    table.size = size * MB / @sizeOf(HashEntry);

    table.data.ensureTotalCapacity(table.size) catch {};
    table.data.expandToCapacity();
}
