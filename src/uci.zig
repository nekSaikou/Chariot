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
const genLegal = @import("movegen.zig").genLegal;
const makeMove = @import("makemove.zig").makeMove;
const searchPos = @import("search.zig").searchPos;
const tt = @import("ttable.zig");

pub fn mainLoop() !void {
    var buf: [2048]u8 = undefined;
    var board: Board = .{};

    while (true) {
        const input = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse break;

        // zig fmt: off
        if (std.mem.startsWith(u8, input, "quit") or std.mem.startsWith(u8, input, "stop")) break
        else if (std.mem.startsWith(u8, input, "ucinewgame")) try parseUCINewGame(&board)
        else if (std.mem.startsWith(u8, input, "uci")) try uciInfo()
        else if (std.mem.startsWith(u8, input, "position")) try parsePosition(&board, input)
        else if (std.mem.startsWith(u8, input, "isready")) try stdout.print("readyok\n", .{})
        else if (std.mem.startsWith(u8, input, "go")) try parseGo(&board, input)
        else if (std.mem.startsWith(u8, input, "setoption")) try parseSetoption(input)
        else { try stdout.print("invalid input: {s}\n", .{input}); continue; }
        // zig fmt: on
    }
}

fn uciInfo() !void {
    try stdout.print("id name Chariot\n", .{});
    try stdout.print("id author Nek\n", .{});
    try stdout.print("uciok\n", .{});
}

fn parseUCINewGame(board: *Board) !void {
    try board.parseFEN(startpos);
    tt.table.clear();
}

pub fn parsePosition(board: *Board, command: []const u8) !void {
    var parts = std.mem.tokenizeSequence(u8, command[9..], " ");
    if (std.mem.eql(u8, parts.next().?, "startpos")) {
        try board.parseFEN(startpos);
        if (parts.peek() == null) return;
        if (std.mem.eql(u8, parts.next().?, "moves")) {
            while (parts.peek() != null) {
                makeMove(board, parseMoveString(board, parts.next().?));
            }
        }
        return;
    } else parts.reset();
    if (std.mem.eql(u8, parts.next().?, "fen")) {
        try board.parseFEN(command[13..]);
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

pub fn parseGo(board: *Board, command: []const u8) !void {
    var parts = std.mem.tokenizeSequence(u8, command[3..], " ");
    var depth: u8 = 1;
    if (std.mem.eql(u8, parts.next().?, "depth"))
        depth = try std.fmt.parseInt(u8, parts.next().?, 10)
    else {
        depth = 6;
    }
    try searchPos(board, depth);
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
