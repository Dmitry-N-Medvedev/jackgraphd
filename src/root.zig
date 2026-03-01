const std = @import("std");
const c = @cImport({
    @cInclude("dbus/dbus.h");
});

extern fn jg_dbus_error_new() ?*c.DBusError;
extern fn jg_dbus_error_free(e: ?*c.DBusError) void;
extern fn jg_dbus_error_message(e: ?*c.DBusError) ?[*:0]const u8;
extern fn jg_dbus_error_is_set(e: ?*c.DBusError) c_int;

extern fn dbus_error_init(err: ?*c.DBusError) void;
extern fn dbus_error_free(err: ?*c.DBusError) void;

fn resetErr(err: ?*c.DBusError) void {
    dbus_error_free(err);
    dbus_error_init(err);
}

fn getBasic(iter: *c.DBusMessageIter, out: anytype) void {
    const p = @as(?*anyopaque, @ptrCast(out));
    c.dbus_message_iter_get_basic(iter, p);
}

fn argTypeName(t: c_int) []const u8 {
    return switch (t) {
        c.DBUS_TYPE_INVALID => "INVALID",
        c.DBUS_TYPE_BYTE => "BYTE",
        c.DBUS_TYPE_BOOLEAN => "BOOLEAN",
        c.DBUS_TYPE_INT16 => "INT16",
        c.DBUS_TYPE_UINT16 => "UINT16",
        c.DBUS_TYPE_INT32 => "INT32",
        c.DBUS_TYPE_UINT32 => "UINT32",
        c.DBUS_TYPE_INT64 => "INT64",
        c.DBUS_TYPE_UINT64 => "UINT64",
        c.DBUS_TYPE_DOUBLE => "DOUBLE",
        c.DBUS_TYPE_STRING => "STRING",
        c.DBUS_TYPE_OBJECT_PATH => "OBJECT_PATH",
        c.DBUS_TYPE_SIGNATURE => "SIGNATURE",
        c.DBUS_TYPE_ARRAY => "ARRAY",
        c.DBUS_TYPE_STRUCT => "STRUCT",
        c.DBUS_TYPE_VARIANT => "VARIANT",
        c.DBUS_TYPE_DICT_ENTRY => "DICT_ENTRY",
        else => "UNKNOWN",
    };
}

fn getBasicChecked(msg: *c.DBusMessage, iter: *c.DBusMessageIter, expected: c_int, out: anytype) bool {
    const actual = c.dbus_message_iter_get_arg_type(iter);
    if (actual != expected) {
        const sig = c.dbus_message_get_signature(msg);
        std.debug.print(
            "DECODE MISMATCH: expected {s} got {s} (signature={s})\n",
            .{ argTypeName(expected), argTypeName(actual), sig },
        );
        return false;
    }
    getBasic(iter, out);
    return true;
}

const DBUS_TIMEOUT_MS = -1;

fn decodePatchbaySignal(msg: ?*c.DBusMessage) void {
    if (msg == null) return;
    if (c.dbus_message_get_type(msg) != c.DBUS_MESSAGE_TYPE_SIGNAL) return;

    const iface_p = c.dbus_message_get_interface(msg);
    const memb_p = c.dbus_message_get_member(msg);
    if (iface_p == null or memb_p == null) return;

    const iface = std.mem.span(iface_p.?);
    const memb = std.mem.span(memb_p.?);

    if (!std.mem.eql(u8, iface, "org.jackaudio.JackPatchbay")) return;

    var iter: c.DBusMessageIter = undefined;
    if (c.dbus_message_iter_init(msg, &iter) == 0) return;

    if (std.mem.eql(u8, memb, "GraphChanged")) {
        var graph: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &graph)) return;
        std.debug.print("PATCHBAY GraphChanged graph={d}\n", .{graph});
        return;
    }

    if (std.mem.eql(u8, memb, "PortsConnected") or std.mem.eql(u8, memb, "PortsDisconnected")) {
        var graph: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &graph)) return;
        _ = c.dbus_message_iter_next(&iter);

        var client1_id: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &client1_id)) return;
        _ = c.dbus_message_iter_next(&iter);

        var client1_name: ?[*:0]const u8 = null;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_STRING, &client1_name)) return;
        _ = c.dbus_message_iter_next(&iter);

        var port1_id: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &port1_id)) return;
        _ = c.dbus_message_iter_next(&iter);

        var port1_name: ?[*:0]const u8 = null;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_STRING, &port1_name)) return;
        _ = c.dbus_message_iter_next(&iter);

        var client2_id: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &client2_id)) return;
        _ = c.dbus_message_iter_next(&iter);

        var client2_name: ?[*:0]const u8 = null;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_STRING, &client2_name)) return;
        _ = c.dbus_message_iter_next(&iter);

        var port2_id: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &port2_id)) return;
        _ = c.dbus_message_iter_next(&iter);

        var port2_name: ?[*:0]const u8 = null;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_STRING, &port2_name)) return;
        _ = c.dbus_message_iter_next(&iter);

        var connection_id: u64 = 0;
        if (!getBasicChecked(msg.?, &iter, c.DBUS_TYPE_UINT64, &connection_id)) return;

        std.debug.print(
            "PATCHBAY {s} graph={d} {s}:{s} -> {s}:{s} conn_id={d}\n",
            .{
                memb_p.?,
                graph,
                client1_name.?,
                port1_name.?,
                client2_name.?,
                port2_name.?,
                connection_id,
            },
        );
        return;
    }
}

pub fn start(allocator: std.mem.Allocator) !void {
    _ = allocator;

    const err = jg_dbus_error_new() orelse return error.OutOfMemory;
    defer jg_dbus_error_free(err);

    const conn = c.dbus_bus_get(c.DBUS_BUS_SESSION, err);
    if (conn == null) return error.DBusConnectFailed;

    std.debug.print("OK: connected to DBus\n", .{});

    resetErr(err);
    c.dbus_bus_add_match(
        conn,
        "type='signal',sender='org.jackaudio.service',path='/org/jackaudio/Controller',interface='org.jackaudio.JackPatchbay'",
        err,
    );
    c.dbus_connection_flush(conn);

    if (jg_dbus_error_is_set(err) != 0) {
        if (jg_dbus_error_message(err)) |m| std.debug.print("ER: dbus_bus_add_match failed: {s}\n", .{m});
        return error.DBusAddMatchFailed;
    }

    std.debug.print("OK: match rule installed\n", .{});

    while (true) {
        _ = c.dbus_connection_read_write_dispatch(conn, DBUS_TIMEOUT_MS);

        const msg = c.dbus_connection_pop_message(conn);
        if (msg == null) continue;
        defer c.dbus_message_unref(msg);

        if (c.dbus_message_get_type(msg) == c.DBUS_MESSAGE_TYPE_SIGNAL) {
            const sender = c.dbus_message_get_sender(msg);
            const iface_dbg = c.dbus_message_get_interface(msg);
            const memb_dbg = c.dbus_message_get_member(msg);
            const serial = c.dbus_message_get_serial(msg);

            // Make both branches the same type ([*c]const u8).
            const sender_print: [*c]const u8 = if (sender != null) sender.? else "?";

            if (iface_dbg != null and memb_dbg != null) {
                std.debug.print(
                    "SIG: {s}.{s} sender={s} serial={d}\n",
                    .{ iface_dbg.?, memb_dbg.?, sender_print, serial },
                );
            }
        }

        decodePatchbaySignal(msg);
    }
}

pub fn stop() void {}
