const Bench = @import("bench.zig").Bench;
const Config = @import("bench.zig").Config;
const std = @import("std");
const Writer = std.fs.File.Writer;

pub fn writeTable(bench: *const Bench, writer: Writer, allocator: std.mem.Allocator) !void {
    const header: [8][]const u8 = .{"Name", "Min", "Max", "Mean", "StdDev", "P50", "P75", "P99"};
    var rows = try std.ArrayList([8][]const u8).initCapacity(allocator, bench.measurements.items.len + 1);
    defer rows.deinit();

    var col_lengths: [8]usize = undefined;

    for (header, 0..) |h, i| {
        col_lengths[i] = h.len + 2;
    }

    for (bench.measurements.items) |*measurement| {
        const row = [8][]const u8{
            try std.fmt.allocPrint(allocator, "{s}", .{measurement.name}),
            try std.fmt.allocPrint(allocator, "{}", .{measurement.min}),
            try std.fmt.allocPrint(allocator, "{}", .{measurement.max}),
            try std.fmt.allocPrint(allocator, "{}", .{measurement.mean}),
            try std.fmt.allocPrint(allocator, "{d:.2}", .{measurement.stdDev}),
            try std.fmt.allocPrint(allocator, "{}", .{measurement.percentile(50)}),
            try std.fmt.allocPrint(allocator, "{}", .{measurement.percentile(75)}),
            try std.fmt.allocPrint(allocator, "{}", .{measurement.percentile(99)}),
        };

        for (row, 0..) |r, i| {
            col_lengths[i] = @max(col_lengths[i], r.len + 2);
        }

        try rows.append(row);
    }

    for (header, col_lengths) |h, l| {
        try writeCell(writer, h, l);
    }

    try writer.writeAll("\n");

    for (col_lengths) |l| {
        try writer.writeByteNTimes('-', l);
    }

    try writer.writeAll("\n");

    for (rows.items) |r| {
        for (r, col_lengths) |c, l| {
            try writeCell(writer, c, l);
            allocator.free(c);
        }

        try writer.writeAll("\n");
    }
}

fn writeCell(writer: Writer, text: []const u8, len: usize) !void {
    const padding = len - text.len;

    try writer.writeAll(text);
    try writer.writeByteNTimes(' ', padding);
}
