const std = @import("std");
const jackgraphd = @import("jackgraphd");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try jackgraphd.start(allocator);
    defer jackgraphd.stop();
}
