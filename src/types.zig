const std = @import("std");
const atk = @import("attacks.zig");
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;

const MAX_PLY: usize = 200;

pub const Board = struct {
    // game state
    side: u1 = 0,
    castlingRights: u4 = 0,
    epSqr: ?u6 = null,
    ply: usize = 0,
    move: usize = 0,

    // bitboards
    pieces: [6]u64 = [_]u64{0} ** 6,
    occupancy: [2]u64 = [_]u64{0} ** 2,

    pub inline fn pieceBB(self: @This(), piece: u3, color: u1) u64 {
        return self.pieces[piece] & self.occupancy[color];
    }

    pub inline fn getAttackers(self: @This(), sqr: u6, color: u1) u64 {
        const occupancy = self.occupancy[0] | self.occupancy[1];
        return (atk.getPawnAttacks(sqr, color ^ 1) & pieceBB(self, 0, color)) |
            (atk.getKnightAttacks(sqr) & (pieceBB(self, 1, color))) |
            (atk.getBishopAttacks(sqr, occupancy) & (pieceBB(self, 2, color))) |
            (atk.getRookAttacks(sqr, occupancy) & (pieceBB(self, 3, color))) |
            (atk.getQueenAttacks(sqr, occupancy) & (pieceBB(self, 4, color))) |
            (atk.getKingAttacks(sqr) & (pieceBB(self, 5, color)));
    }

    pub fn parseFEN(self: *@This(), str: []const u8) !void {
        self.* = Board{};

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
    moves: [256]ScoredMove = undefined,
    count: usize = 0,
};

pub const ScoredMove = struct {
    move: Move = .{},
    piece: u3 = 0,
    score: i32 = 0,
};

pub const Move = packed struct(u16) {
    src: u6 = 0,
    dest: u6 = 0,
    promo: u1 = 0,
    capture: u1 = 0,
    specA: u1 = 0, // responsible for castling and promotion flags
    specB: u1 = 0, // responsible for ep/dp and promotion flags

    //  code 	promo   capture	specA  	specB  	kind of move
    //  0 	0 	0 	0 	0 	quiet moves
    //  1 	0 	0 	0 	1 	double pawn push
    //  2 	0 	0 	1 	0 	king castle
    //  3 	0 	0 	1 	1 	queen castle
    //  4 	0 	1 	0 	0 	captures
    //  5 	0 	1 	0 	1 	ep-capture
    //  8 	1 	0 	0 	0 	knight-promotion
    //  9 	1 	0 	0 	1 	bishop-promotion
    //  10 	1 	0 	1 	0 	rook-promotion
    //  11 	1 	0 	1 	1 	queen-promotion
    //  12 	1 	1 	0 	0 	knight-promo capture
    //  13 	1 	1 	0 	1 	bishop-promo capture
    //  14 	1 	1 	1 	0 	rook-promo capture
    //  15 	1 	1 	1 	1 	queen-promo capture
};

pub const Square = enum(u6) {
    // zig fmt: off
    a8, b8, c8, d8, e8, f8, g8, h8,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a1, b1, c1, d1, e1, f1, g1, h1
    // zig fmt: on
};
