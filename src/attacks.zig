const std = @import("std");
const util = @import("util.zig");
const getBit = @import("util.zig").getBit;
const setBit = @import("util.zig").setBit;
const popBit = @import("util.zig").popBit;
const pieceBB = @import("util.zig").pieceBB;
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;

// leaper pieces attack tables
var pawnAttacks: [64][2]u64 = undefined;
var knightAttacks: [64]u64 = undefined;
var kingAttacks: [64]u64 = undefined;
// sliding pieces attack tables
var bishopAttacks: [64][512]u64 = undefined;
var rookAttacks: [64][4096]u64 = undefined;
// sliding pieces attack masks
var bishopMasks: [64]u64 = undefined;
var rookMasks: [64]u64 = undefined;

pub inline fn getAttackers(board: Board, sqr: u6, color: u1) u64 {
    const occupancy = board.occupancy[0] | board.occupancy[1];
    return (getPawnAttacks(sqr, color ^ 1) & pieceBB(board, 0, color)) |
        (getKnightAttacks(sqr) & (pieceBB(board, 1, color))) |
        (getBishopAttacks(sqr, occupancy) & (pieceBB(board, 2, color))) |
        (getRookAttacks(sqr, occupancy) & (pieceBB(board, 3, color))) |
        (getQueenAttacks(sqr, occupancy) & (pieceBB(board, 4, color))) |
        (getKingAttacks(sqr) & (pieceBB(board, 5, color)));
}

pub inline fn getPawnAttacks(sqr: u6, color: u1) u64 {
    return pawnAttacks[sqr][color];
}

pub inline fn getKnightAttacks(sqr: u6) u64 {
    return knightAttacks[sqr];
}

pub inline fn getKingAttacks(sqr: u6) u64 {
    return kingAttacks[sqr];
}

pub inline fn getBishopAttacks(sqr: u6, occupancy_: u64) u64 {
    var occupancy: u64 = occupancy_;

    occupancy &= bishopMasks[sqr];
    occupancy = @mulWithOverflow(occupancy, bishopMagic[sqr])[0];
    occupancy >>= @as(u6, @intCast(@as(u7, 64) - bishopRelevantBits[sqr]));

    return bishopAttacks[sqr][occupancy];
}

pub inline fn getRookAttacks(sqr: u6, occupancy_: u64) u64 {
    var occupancy: u64 = occupancy_;

    occupancy &= rookMasks[sqr];
    occupancy = @mulWithOverflow(occupancy, rookMagic[sqr])[0];
    occupancy >>= @as(u6, @intCast(@as(u7, 64) - rookRelevantBits[sqr]));

    return rookAttacks[sqr][occupancy];
}

pub inline fn getQueenAttacks(sqr: u6, occupancy: u64) u64 {
    return getRookAttacks(sqr, occupancy) | getBishopAttacks(sqr, occupancy);
}

fn genPawnAttacks(sqr: u6, color: u1) u64 {
    var attacks: u64 = 0;
    var bitboard: u64 = 0;

    setBit(&bitboard, sqr);

    switch (color) {
        0 => {
            if (bitboard & notHFile != 0) attacks |= (bitboard >> 7);
            if (bitboard & notAFile != 0) attacks |= (bitboard >> 9);
        },
        1 => {
            if (bitboard & notAFile != 0) attacks |= (bitboard << 7);
            if (bitboard & notHFile != 0) attacks |= (bitboard << 9);
        },
    }
    return attacks;
}

fn genKnightAttacks(sqr: u6) u64 {
    var attacks: u64 = 0;
    var bitboard: u64 = 0;

    setBit(&bitboard, sqr);

    if (bitboard & notGHFile != 0) {
        attacks |= (bitboard >> 6);
        attacks |= (bitboard << 10);
    }
    if (bitboard & notABFile != 0) {
        attacks |= (bitboard >> 10);
        attacks |= (bitboard << 6);
    }
    if (bitboard & notHFile != 0) {
        attacks |= (bitboard >> 15);
        attacks |= (bitboard << 17);
    }
    if (bitboard & notAFile != 0) {
        attacks |= (bitboard >> 17);
        attacks |= (bitboard << 15);
    }

    return attacks;
}

fn genKingAttacks(sqr: u6) u64 {
    var attacks: u64 = 0;
    var bitboard: u64 = 0;

    setBit(&bitboard, sqr);

    attacks |= (bitboard << 8);
    attacks |= (bitboard >> 8);
    if (bitboard & notHFile != 0) {
        attacks |= (bitboard >> 7);
        attacks |= (bitboard << 1);
        attacks |= (bitboard << 9);
    }
    if (bitboard & notAFile != 0) {
        attacks |= (bitboard >> 9);
        attacks |= (bitboard >> 1);
        attacks |= (bitboard << 7);
    }
    return attacks;
}

fn initLeaperAttacks() void {
    for (0..64) |sqr| {
        // initialize pawn attacks
        pawnAttacks[sqr][0] = genPawnAttacks(@intCast(sqr), 0);
        pawnAttacks[sqr][1] = genPawnAttacks(@intCast(sqr), 1);
        // initialize knight attacks
        knightAttacks[sqr] = genKnightAttacks(@intCast(sqr));
        // initialize king attacks
        kingAttacks[sqr] = genKingAttacks(@intCast(sqr));
    }
}

pub fn genBishopMasks(sqr: u6) u64 {
    var attacks: u64 = 0;

    const targetRank: i32 = @intCast(sqr / 8);
    const targetFile: i32 = @intCast(sqr % 8);

    var rank: i32 = targetRank + 1;
    var file: i32 = targetFile + 1;
    while (rank <= 6 and file <= 6) {
        setBit(&attacks, @intCast(rank * 8 + file));
        rank += 1;
        file += 1;
    }

    rank = targetRank - 1;
    file = targetFile + 1;
    while (rank >= 1 and file <= 6) {
        setBit(&attacks, @intCast(rank * 8 + file));
        rank -= 1;
        file += 1;
    }

    rank = targetRank + 1;
    file = targetFile - 1;
    while (rank <= 6 and file >= 1) {
        setBit(&attacks, @intCast(rank * 8 + file));
        rank += 1;
        file -= 1;
    }

    rank = targetRank - 1;
    file = targetFile - 1;
    while (rank >= 1 and file >= 1) {
        setBit(&attacks, @intCast(rank * 8 + file));
        rank -= 1;
        file -= 1;
    }

    return attacks;
}

pub fn genRookMasks(sqr: u6) u64 {
    var attacks: u64 = 0;

    const targetRank: i32 = @intCast(sqr / 8);
    const targetFile: i32 = @intCast(sqr % 8);

    var rank: i32 = targetRank + 1;
    while (rank <= 6) {
        setBit(&attacks, @intCast(rank * 8 + targetFile));
        rank += 1;
    }
    rank = targetRank - 1;
    while (rank >= 1) {
        setBit(&attacks, @intCast(rank * 8 + targetFile));
        rank -= 1;
    }
    var file: i32 = targetFile + 1;
    while (file <= 6) {
        setBit(&attacks, @intCast(targetRank * 8 + file));
        file += 1;
    }
    file = targetFile - 1;
    while (file >= 1) {
        setBit(&attacks, @intCast(targetRank * 8 + file));
        file -= 1;
    }

    return attacks;
}

fn genBishopAttacks(sqr: u6, block: u64) u64 {
    var attacks: u64 = 0;

    const targetRank: i32 = @intCast(sqr / 8);
    const targetFile: i32 = @intCast(sqr % 8);

    var rank: i32 = targetRank + 1;
    var file: i32 = targetFile + 1;
    while (rank <= 7 and file <= 7) {
        setBit(&attacks, @intCast(rank * 8 + file));
        if ((@as(u64, 1) << @intCast(rank * 8 + file)) & block != 0) {
            break;
        }
        rank += 1;
        file += 1;
    }
    rank = targetRank - 1;
    file = targetFile + 1;
    while (rank >= 0 and file <= 7) {
        setBit(&attacks, @intCast(rank * 8 + file));
        if ((@as(u64, 1) << @intCast(rank * 8 + file)) & block != 0) {
            break;
        }
        rank -= 1;
        file += 1;
    }
    rank = targetRank + 1;
    file = targetFile - 1;
    while (rank <= 7 and file >= 0) {
        setBit(&attacks, @intCast(rank * 8 + file));
        if ((@as(u64, 1) << @intCast(rank * 8 + file)) & block != 0) {
            break;
        }
        rank += 1;
        file -= 1;
    }
    rank = targetRank - 1;
    file = targetFile - 1;
    while (rank >= 0 and file >= 0) {
        setBit(&attacks, @intCast(rank * 8 + file));
        if ((@as(u64, 1) << @intCast(rank * 8 + file)) & block != 0) {
            break;
        }
        rank -= 1;
        file -= 1;
    }

    return attacks;
}

fn genRookAttacks(sqr: u6, block: u64) u64 {
    var attacks: u64 = 0;

    const targetRank: i32 = @intCast(sqr / 8);
    const targetFile: i32 = @intCast(sqr % 8);

    var rank: i32 = targetRank + 1;
    while (rank <= 7) {
        setBit(&attacks, @intCast(rank * 8 + targetFile));
        if ((@as(u64, 1) << @intCast(rank * 8 + targetFile)) & block != 0) {
            break;
        }
        rank += 1;
    }
    rank = targetRank - 1;
    while (rank >= 0) {
        setBit(&attacks, @intCast(rank * 8 + targetFile));
        if ((@as(u64, 1) << @intCast(rank * 8 + targetFile)) & block != 0) {
            break;
        }
        rank -= 1;
    }
    var file: i32 = targetFile + 1;
    while (file <= 7) {
        setBit(&attacks, @intCast(targetRank * 8 + file));
        if ((@as(u64, 1) << @intCast(targetRank * 8 + file)) & block != 0) {
            break;
        }
        file += 1;
    }
    file = targetFile - 1;
    while (file >= 0) {
        setBit(&attacks, @intCast(targetRank * 8 + file));
        if ((@as(u64, 1) << @intCast(targetRank * 8 + file)) & block != 0) {
            break;
        }
        file -= 1;
    }

    return attacks;
}

fn setOccupancy(index: usize, attackMask_: u64) u64 {
    var attackMask = attackMask_;
    var occupancy: u64 = 0;
    for (0..@popCount(attackMask_)) |count| {
        var sqr: u6 = @intCast(@ctz(attackMask));
        popBit(&attackMask, sqr);

        if ((index & (@as(u64, 1) << @intCast(count))) != 0) {
            occupancy |= (@as(u64, 1) << sqr);
        }
    }
    return occupancy;
}

fn initSliderAttacks(piece: u1) void {
    for (0..64) |sqr| {
        bishopMasks[sqr] = genBishopMasks(@intCast(sqr));
        rookMasks[sqr] = genRookMasks(@intCast(sqr));
        const attackMask = switch (piece) {
            0 => bishopMasks[sqr],
            1 => rookMasks[sqr],
        };

        const relevantBits = @popCount(attackMask);
        const occupancyIndex = @as(u64, 1) << @as(u6, @intCast(relevantBits));

        var index: usize = 0;
        while (index < occupancyIndex) : (index += 1) {
            switch (piece) {
                0 => {
                    const occupancy = setOccupancy(index, attackMask);
                    const res = @mulWithOverflow(occupancy, bishopMagic[sqr])[0];
                    const magicIndex = res >> @as(u6, @intCast(@as(u7, 64) - bishopRelevantBits[sqr]));

                    bishopAttacks[sqr][magicIndex] = genBishopAttacks(@intCast(sqr), occupancy);
                },
                1 => {
                    const occupancy = setOccupancy(index, attackMask);
                    const res = @mulWithOverflow(occupancy, rookMagic[sqr])[0];
                    const magicIndex = res >> @as(u6, @intCast(@as(u7, 64) - rookRelevantBits[sqr]));

                    rookAttacks[sqr][magicIndex] = genRookAttacks(@intCast(sqr), occupancy);
                },
            }
        }
    }
}

pub fn initAll() void {
    initLeaperAttacks();
    initSliderAttacks(0);
    initSliderAttacks(1);
}

const bishopRelevantBits = [64]usize{
    // zig fmt: off
    6, 5, 5, 5, 5, 5, 5, 6, 
    5, 5, 5, 5, 5, 5, 5, 5, 
    5, 5, 7, 7, 7, 7, 5, 5, 
    5, 5, 7, 9, 9, 7, 5, 5, 
    5, 5, 7, 9, 9, 7, 5, 5, 
    5, 5, 7, 7, 7, 7, 5, 5, 
    5, 5, 5, 5, 5, 5, 5, 5, 
    6, 5, 5, 5, 5, 5, 5, 6
    // zig fmt: on
};

const rookRelevantBits = [64]usize{
    // zig fmt: off
    12, 11, 11, 11, 11, 11, 11, 12, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    11, 10, 10, 10, 10, 10, 10, 11, 
    12, 11, 11, 11, 11, 11, 11, 12
    // zig fmt: on
};

pub const bishopMagic = [64]u64{
    0x89a1121896040240, 0x2004844802002010, 0x2068080051921000, 0x62880a0220200808, 0x4042004000000,
    0x100822020200011,  0xc00444222012000a, 0x28808801216001,   0x400492088408100,  0x201c401040c0084,
    0x840800910a0010,   0x82080240060,      0x2000840504006000, 0x30010c4108405004, 0x1008005410080802,
    0x8144042209100900, 0x208081020014400,  0x4800201208ca00,   0xf18140408012008,  0x1004002802102001,
    0x841000820080811,  0x40200200a42008,   0x800054042000,     0x88010400410c9000, 0x520040470104290,
    0x1004040051500081, 0x2002081833080021, 0x400c00c010142,    0x941408200c002000, 0x658810000806011,
    0x188071040440a00,  0x4800404002011c00, 0x104442040404200,  0x511080202091021,  0x4022401120400,
    0x80c0040400080120, 0x8040010040820802, 0x480810700020090,  0x102008e00040242,  0x809005202050100,
    0x8002024220104080, 0x431008804142000,  0x19001802081400,   0x200014208040080,  0x3308082008200100,
    0x41010500040c020,  0x4012020c04210308, 0x208220a202004080, 0x111040120082000,  0x6803040141280a00,
    0x2101004202410000, 0x8200000041108022, 0x21082088000,      0x2410204010040,    0x40100400809000,
    0x822088220820214,  0x40808090012004,   0x910224040218c9,   0x402814422015008,  0x90014004842410,
    0x1000042304105,    0x10008830412a00,   0x2520081090008908, 0x40102000a0a60140,
};

pub const rookMagic = [64]u64{
    0xa8002c000108020,  0x6c00049b0002001,  0x100200010090040,  0x2480041000800801, 0x280028004000800,
    0x900410008040022,  0x280020001001080,  0x2880002041000080, 0xa000800080400034, 0x4808020004000,
    0x2290802004801000, 0x411000d00100020,  0x402800800040080,  0xb000401004208,    0x2409000100040200,
    0x1002100004082,    0x22878001e24000,   0x1090810021004010, 0x801030040200012,  0x500808008001000,
    0xa08018014000880,  0x8000808004000200, 0x201008080010200,  0x801020000441091,  0x800080204005,
    0x1040200040100048, 0x120200402082,     0xd14880480100080,  0x12040280080080,   0x100040080020080,
    0x9020010080800200, 0x813241200148449,  0x491604001800080,  0x100401000402001,  0x4820010021001040,
    0x400402202000812,  0x209009005000802,  0x810800601800400,  0x4301083214000150, 0x204026458e001401,
    0x40204000808000,   0x8001008040010020, 0x8410820820420010, 0x1003001000090020, 0x804040008008080,
    0x12000810020004,   0x1000100200040208, 0x430000a044020001, 0x280009023410300,  0xe0100040002240,
    0x200100401700,     0x2244100408008080, 0x8000400801980,    0x2000810040200,    0x8010100228810400,
    0x2000009044210200, 0x4080008040102101, 0x40002080411d01,   0x2005524060000901, 0x502001008400422,
    0x489a000810200402, 0x1004400080a13,    0x4000011008020084, 0x26002114058042,
};

const notAFile: u64 = 0xfefefefefefefefe;
const notHFile: u64 = 0x7f7f7f7f7f7f7f7f;
const notABFile: u64 = 0xfcfcfcfcfcfcfcfc;
const notGHFile: u64 = 0x3f3f3f3f3f3f3f3f;
