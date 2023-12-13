const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const getBit = @import("bitboard.zig").getBit;
const setBit = @import("bitboard.zig").setBit;
const popBit = @import("bitboard.zig").popBit;
const atk = @import("attacks.zig");
const Move = @import("types.zig").Move;
const ScoredMove = @import("types.zig").ScoredMove;
const MoveList = @import("types.zig").MoveList;
const Board = @import("types.zig").Board;
const Square = @import("types.zig").Square;
const ThreadData = @import("types.zig").ThreadData;
const SearchInfo = @import("types.zig").SearchInfo;
const genLegal = @import("movegen.zig").genLegal;
const makeMove = @import("makemove.zig").makeMove;
const tt = @import("ttable.zig");
const perftTest = @import("perft.zig").perftTest;
const search = @import("search.zig").deepening;
const TTable = @import("ttable.zig").TTable;

var ttable: TTable = .{};
var pos: Board = .{};
var info: SearchInfo = .{};

pub fn mainLoop() !void {
    var buf: [2048]u8 = undefined;
    var td: ThreadData = .{ .ttable = &ttable, .board = &pos, .searchInfo = &info };
    ttable.initTT(16);

    while (true) {
        const input = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse break;

        // zig fmt: off
        try if (std.mem.startsWith(u8, input, "quit"))  break
        else if (std.mem.startsWith(u8, input, "stop")) {td.searchInfo.stop = true;}
        else if (std.mem.startsWith(u8, input, "ucinewgame")) parseUCINewGame(&td)
        else if (std.mem.startsWith(u8, input, "uci")) try uciInfo()
        else if (std.mem.startsWith(u8, input, "position")) parsePosition(&td, input)
        else if (std.mem.startsWith(u8, input, "isready")) try stdout.print("readyok\n", .{})
        else if (std.mem.startsWith(u8, input, "go")) try parseGo(&td, input)
        else if (std.mem.startsWith(u8, input, "setoption")) try parseSetoption(input)
        else { try stdout.print("invalid input: {s}\n", .{input}); continue; };
        // zig fmt: on
    }
}

fn uciInfo() !void {
    try stdout.print("id name Chariot\n", .{});
    try stdout.print("id author Nek\n", .{});
    try stdout.print("uciok\n", .{});
}

fn parseUCINewGame(td: *ThreadData) void {
    ttable.clear();
    td.* = .{ .ttable = &ttable, .board = &pos, .searchInfo = &info };
    td.board.parseFEN(startpos);
}

pub fn parsePosition(td: *ThreadData, command: []const u8) !void {
    var board: *Board = td.board;
    var parts = std.mem.tokenizeSequence(u8, command[9..], " ");
    if (std.mem.eql(u8, parts.next().?, "startpos")) {
        board.parseFEN(startpos);
        if (parts.peek() == null) return;
        if (std.mem.eql(u8, parts.next().?, "moves")) {
            while (parts.peek() != null) {
                makeMove(board, parseMoveString(board, parts.next().?));
            }
        }
        return;
    } else parts.reset();
    if (std.mem.eql(u8, parts.next().?, "fen")) {
        board.parseFEN(command[13..]);
        while (parts.peek() != null and !std.mem.eql(u8, parts.peek().?, "moves")) _ = parts.next();
        if (parts.peek() != null and std.mem.eql(u8, parts.next().?, "moves")) {
            while (parts.peek() != null) {
                makeMove(board, parseMoveString(board, parts.next().?));
            }
        }
        return;
    } else parts.reset();
}

pub fn parseSetoption(command: []const u8) !void {
    _ = command;
    //TODO: implement options
}

pub fn parseGo(td: *ThreadData, command: []const u8) !void {
    var parts = std.mem.tokenizeSequence(u8, command[3..], " ");
    var depth: ?u8 = null;
    var time: ?usize = null;
    var inc: ?usize = null;
    var movestogo: ?usize = null;
    var movetime: ?usize = null;

    td.searchInfo.* = .{};
    while (true) {
        var part = parts.next();
        if (part == null) break;
        if (std.mem.eql(u8, part.?, "infinite")) {
            td.searchInfo.infinite = true;
        }
        if (std.mem.eql(u8, part.?, "depth")) {
            part = parts.next();
            if (part == null) break;
            depth = std.fmt.parseUnsigned(u8, part.?, 10) catch 5;
        }
        if (std.mem.eql(u8, part.?, "wtime") and td.board.side == 0) {
            part = parts.next();
            if (part == null) break;
            time = std.fmt.parseUnsigned(usize, part.?, 10) catch unreachable;
        }
        if (std.mem.eql(u8, part.?, "btime") and td.board.side == 1) {
            part = parts.next();
            if (part == null) break;
            time = std.fmt.parseUnsigned(usize, part.?, 10) catch unreachable;
        }
        if (std.mem.eql(u8, part.?, "winc") and td.board.side == 0) {
            part = parts.next();
            if (part == null) break;
            inc = std.fmt.parseUnsigned(usize, part.?, 10) catch unreachable;
        }
        if (std.mem.eql(u8, part.?, "binc") and td.board.side == 1) {
            part = parts.next();
            if (part == null) break;
            inc = std.fmt.parseUnsigned(usize, part.?, 10) catch unreachable;
        }
        if (std.mem.eql(u8, part.?, "movetime")) {
            part = parts.next();
            if (part == null) break;
            movetime = std.fmt.parseUnsigned(usize, part.?, 10) catch unreachable;
        }
        if (std.mem.eql(u8, part.?, "movestogo")) {
            part = parts.next();
            if (part == null) break;
            movestogo = std.fmt.parseUnsigned(usize, part.?, 10) catch unreachable;
        }
    }

    if (movetime != null) {
        time = movetime.?;
        movestogo = 1;
    }

    td.searchInfo.depth = depth orelse 40;

    if (time != null) {
        time.? /= (movestogo orelse 25);
        td.searchInfo.timeset = true;
        td.searchInfo.timeLim = time.? - 100 + (inc orelse 0);
    }

    search(td);
}

pub fn uciMove(move: Move) []const u8 {
    const src: []const u8 = @tagName(@as(Square, @enumFromInt(move.src)));
    const dest: []const u8 = @tagName(@as(Square, @enumFromInt(move.dest)));

    var output: [5]u8 = undefined;
    std.mem.copy(u8, output[0..], src);
    std.mem.copy(u8, output[2..], dest);

    if (!move.isPromo()) return output[0..4];

    const promo: []const u8 = switch (move.getPromoType()) {
        1 => "n",
        2 => "b",
        3 => "r",
        4 => "q",
        else => unreachable,
    };
    std.mem.copy(u8, output[4..], promo);
    return output[0..5];
}

fn parseMoveString(board: *Board, str: []const u8) Move {
    var list: MoveList = .{};
    genLegal(board, &list);

    const src: u6 = @intCast((str[0] - 'a') + (8 - (str[1] - '0')) * 8);
    const dest: u6 = @intCast((str[2] - 'a') + (8 - (str[3] - '0')) * 8);
    for (0..list.count) |count| {
        const move: Move = list.moves[count].move;
        if (move.src == src and move.dest == dest) {
            if (str.len == 4) return move;
            if (str[4] == 'q' and (move.getPromoType() == 4)) return move;
            if (str[4] == 'r' and (move.getPromoType() == 3)) return move;
            if (str[4] == 'b' and (move.getPromoType() == 2)) return move;
            if (str[4] == 'n' and (move.getPromoType() == 1)) return move;
        }
    }
    unreachable;
}

pub const startpos = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ";
