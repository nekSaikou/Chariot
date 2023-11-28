const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const util = @import("util.zig");
const atk = @import("attacks.zig");
const Board = @import("types.zig").Board;
const Move = @import("types.zig").Move;
const MoveList = @import("types.zig").MoveList;
const Square = @import("types.zig").Square;
const moves = @import("moves.zig");
const search = @import("search.zig");

pub fn mainLoop() !void {
    var buf: [2048]u8 = undefined;
    var board: Board = .{};

    while (true) {
        const input = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse break;

        // zig fmt: off
        if (std.mem.startsWith(u8, input, "quit")) break
        else if (std.mem.startsWith(u8, input, "ucinewgame")) try board.parseFEN(startpos)
        else if (std.mem.startsWith(u8, input, "uci")) try uciInfo()
        else if (std.mem.startsWith(u8, input, "position")) try parsePosition(&board, input)
        else if (std.mem.startsWith(u8, input, "isready")) try stdout.print("readyok\n", .{})
        else if (std.mem.startsWith(u8, input, "go")) try parseGo(&board, input)
        else { try stdout.print("invalid input: {s}\n", .{input}); continue; }
        // zig fmt: on
    }
}

pub fn uciInfo() !void {
    try stdout.print("id name Chariot\n", .{});
    try stdout.print("id author Nek\n", .{});
    try stdout.print("uciok\n", .{});
}

pub fn parseGo(board: *Board, command: []const u8) !void {
    var parts = std.mem.tokenizeSequence(u8, command[3..], " ");
    var depth: i8 = -1;
    if (std.mem.eql(u8, parts.next().?, "depth"))
        depth = try std.fmt.parseInt(i8, parts.next().?, 10)
    else
        depth = 5;
    try search.searchPos(board, depth);
}

pub fn parsePosition(board: *Board, command: []const u8) !void {
    var parts = std.mem.tokenizeSequence(u8, command[9..], " ");
    if (std.mem.eql(u8, parts.next().?, "startpos")) {
        try board.parseFEN(startpos);
        if (parts.peek() == null) return;
        if (std.mem.eql(u8, parts.next().?, "moves")) {
            while (parts.peek() != null) {
                _ = moves.makeMove(board, parseMoveString(board.*, parts.next().?), true);
            }
        }
        return;
    } else parts.reset();
    if (std.mem.eql(u8, parts.next().?, "fen")) {
        try board.parseFEN(command[13..]);
        while (!std.mem.eql(u8, parts.peek().?, "moves") and parts.peek() != null) _ = parts.next();
        if (std.mem.eql(u8, parts.next().?, "moves")) {
            while (parts.peek() != null) {
                _ = moves.makeMove(board, parseMoveString(board.*, parts.next().?), true);
            }
        }
        return;
    } else parts.reset();
}

fn parseMoveString(board: Board, str: []const u8) Move {
    var moveList: MoveList = .{};
    moves.genPseudoLegal(board, &moveList);

    const src: u6 = @intCast((str[0] - 'a') + (8 - (str[1] - '0')) * 8);
    const dest: u6 = @intCast((str[2] - 'a') + (8 - (str[3] - '0')) * 8);
    for (0..moveList.count) |count| {
        const move: Move = moveList.moves[count];
        if (move.src == src and move.dest == dest) {
            if (str.len == 4) return move;
            if (str[4] == 'q' and (move.promo == 4)) return move;
            if (str[4] == 'r' and (move.promo == 3)) return move;
            if (str[4] == 'b' and (move.promo == 2)) return move;
            if (str[4] == 'n' and (move.promo == 1)) return move;
        }
    }
    unreachable;
}

pub fn printBestMove(move: Move) !void {
    try stdout.print("bestmove {s}{s}", .{
        @tagName(@as(Square, @enumFromInt(move.src))),
        @tagName(@as(Square, @enumFromInt(move.dest))),
    });
    if (move.promo != 0)
        try stdout.print("{c}", .{getPromo(move)});
    try stdout.print("\n", .{});
}

fn getPromo(move: Move) u8 {
    switch (move.promo) {
        1 => return 'n',
        2 => return 'b',
        3 => return 'r',
        4 => return 'q',
        else => unreachable,
    }
}

pub const startpos = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ";
