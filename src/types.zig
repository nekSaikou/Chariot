const std = @import("std");
const util = @import("util.zig");
const getBit = util.getBit;
const setBit = util.setBit;
const popBit = util.popBit;
const pieceBB = util.pieceBB;

pub const Board = struct {
    // game state
    side: u1,
    castlingRights: u4,
    epSqr: ?u6,

    // bitboards
    pieces: [6]u64,
    occupancy: [2]u64,

    pub fn kingSqr(self: @This(), color: u1) u6 {
        return @intCast(@ctz(self.pieces[5] & self.occupancy[color]));
    }

    pub fn parseFEN(self: *@This(), str: []const u8) !void {
        @memset(&self.pieces, 0);
        @memset(&self.occupancy, 0);

        var rank: u6 = 0;
        var file: u6 = 0;
        var index: usize = 0;
        while (index < str.len) : ({
            index += 1;
            if (str[index - 1] != '/' and index != 0) file += 1;
        }) {
            const char = str[index];
            switch (char) {
                '0'...'9' => {
                    file += try std.fmt.parseUnsigned(u6, str[index..(index + 1)], 10) - 1;
                },
                'P', 'N', 'B', 'R', 'Q', 'K' => {
                    const sqr = @as(u6, rank * 8 + file);
                    setBit(&self.occupancy[0], sqr);
                    switch (char) {
                        'P' => setBit(&self.pieces[0], sqr),
                        'N' => setBit(&self.pieces[1], sqr),
                        'B' => setBit(&self.pieces[2], sqr),
                        'R' => setBit(&self.pieces[3], sqr),
                        'Q' => setBit(&self.pieces[4], sqr),
                        'K' => setBit(&self.pieces[5], sqr),
                        else => unreachable,
                    }
                },
                'p', 'n', 'b', 'r', 'q', 'k' => {
                    const sqr = @as(u6, rank * 8 + file);
                    setBit(&self.occupancy[1], sqr);
                    switch (char) {
                        'p' => setBit(&self.pieces[0], sqr),
                        'n' => setBit(&self.pieces[1], sqr),
                        'b' => setBit(&self.pieces[2], sqr),
                        'r' => setBit(&self.pieces[3], sqr),
                        'q' => setBit(&self.pieces[4], sqr),
                        'k' => setBit(&self.pieces[5], sqr),
                        else => unreachable,
                    }
                },
                '/' => {
                    rank += 1;
                    file = 0;
                },
                ' ' => break,
                else => unreachable,
            }
        }
        var parts = std.mem.tokenizeSequence(u8, str[index..], " ");
        // side to move
        const side = parts.next().?[0];
        switch (side) {
            'w' => self.side = 0,
            'b' => self.side = 1,
            else => unreachable,
        }
        // castling rights
        const castling = parts.next().?;
        for (castling) |char| {
            switch (char) {
                'K' => self.castlingRights |= 0b0001,
                'Q' => self.castlingRights |= 0b0010,
                'k' => self.castlingRights |= 0b0100,
                'q' => self.castlingRights |= 0b1000,
                '-' => break,
                else => unreachable,
            }
        }
        const enpassant = parts.next().?;
        if (enpassant[0] != '-') {
            const r = 8 - @as(u6, @intCast(try std.fmt.parseUnsigned(u3, enpassant[1..], 10)));
            const f = enpassant[0] - 'a';
            self.epSqr = @intCast(r * 8 + f);
        } else self.epSqr = null;
    }
};

pub const MoveList = struct {
    moves: [256]Move = undefined,
    count: usize = 0,
};

pub const Move = packed struct(u22) {
    src: u6,
    dest: u6,
    piece: u3,
    promo: u3 = 0,
    capture: u1 = 0,
    double: u1 = 0,
    enpassant: u1 = 0,
    castling: u1 = 0,
};
