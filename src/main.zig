const std = @import("std");

const ZignoreError = error {
    IgnoreFileNotFound
};

const GPA = std.heap.GeneralPurposeAllocator;
const Error = ZignoreError;
const UTF8String = std.ArrayList(u8);

const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const argsWithAllocator = std.process.argsWithAllocator;
const Client = std.http.Client;
const Status = std.http.Status;

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdIn().writer();

const HEADER_BUFFER_LEN = 8192;
const BASE_URL = "https://raw.githubusercontent.com/github/gitignore/refs/heads/main/";

pub fn main() !void {
    var gpa = GPA(.{}) {};
    defer if (gpa.deinit() == .leak) @panic("Memory leak detected.");
    const allocator = gpa.allocator();

    var args = try argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    var arg = args.next();

    var client = Client { .allocator = allocator };
    defer client.deinit();

    var location = try UTF8String.initCapacity(allocator, BASE_URL.len);
    defer location.deinit();

    var text = UTF8String.init(allocator);
    defer text.deinit();

    while (arg != null) : (arg = args.next()) {
        try location.resize(0);
        try location.appendSlice(BASE_URL);
        try location.appendSlice(arg.?);

        makeOne(&client, location.items, &text) catch |err| {
            if (err != Error.IgnoreFileNotFound) {
                return err;
            }
            try stdout.print("Using {s} as full url...", .{arg.?});
            try makeOne(&client, arg.?, &text);
        };
        const endl = if (text.items[text.items.len - 1] == '\n') "" else "\n";
        try stdout.print(
            "\n=== start {s} ===\n" ++
            "{s}{s}" ++
            "=== end {s} ===\n",
            .{
                arg.?,
                text.items,
                endl,
                arg.?
            }
        );
    }
}

fn makeOne(client: *Client, location: []const u8, text: *UTF8String) !void {
    var headerBuffer: [HEADER_BUFFER_LEN]u8 = undefined;
    try text.resize(0);
    const result = try client.fetch(.{
        .location = .{ .url = location },
        .server_header_buffer = &headerBuffer,
        .response_storage = .{ .dynamic = text }
    });

    if (result.status != Status.ok) {
        return Error.IgnoreFileNotFound;
    }
}

