const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const m = @import("math.zig");
const assets = @import("assets.zig");
const conf = @import("config.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const sys = @import("system.zig");
const esc = @import("esc_engine.zig");
const utils = @import("utils.zig");



pub const Item = struct {
    shape: [5]?@Vector(2, u8) = .{ .{ 0, 0 }, null, null, null, null },
    pos: ?@Vector(2, u8) = null,
    id: usize,
    tex: *rl.Texture2D,
    name: [:0]const u8,
    type: ItemType,

    const ItemType = union(enum) {
        // Weapon: Weapon,
        // WeaponBuff: (*const fn (*Weapon) void),
    };

};

pub const bw = 5;
pub const bh = 5;
pub const blk_size = m.srl2sizen(.{ .x = 32 * conf.pixelMul, .y = 32 * conf.pixelMul });
var inventory = [_][bw]?usize{[_]?usize{null} ** bw} ** bh;
const Items = std.AutoArrayHashMap(usize, Item);
var items: Items = undefined;
var item_id: usize = 0;
var selected_item: ?usize = null;
fn DrawText(v: m.Vec2, text: [:0]const u8, font_size: u8, color: rl.Color) void {
    const pos = m.coordn2srl(v);
    rl.DrawText(text, @intFromFloat(pos.x), @intFromFloat(pos.y), font_size, color);
}
fn DrawItem(item: Item, pos: m.Vec2) void {
    //  q
    const spos = m.coordn2srl(pos - blk_size / m.splat(2));
    rl.DrawTextureEx(item.tex.*, spos, 0, conf.pixelMul, rl.WHITE);
}
fn checkItemBound(bc: @Vector(2, i32)) bool {
    return bc[0] >= 0 and bc[1] >= 0 and bc[0] < bw and bc[1] < bh;
}
fn checkItemOccupied(bc: @Vector(2, u8)) bool {
    return inventory[bc[0]][bc[1]] == null;
}
fn tryPlaceItem(bc: @Vector(2, i32), si: *Item) bool {
    for (si.shape) |shape_coord| {
        const c = bc + (shape_coord orelse @Vector(2, u8){ 0, 0 });
        if (!checkItemBound(c) or !checkItemOccupied(@intCast(c))) {
            return false;
        }
    } else {
        dropItem(si);
        si.pos = .{ @intCast(bc[0]), @intCast(bc[1]) };
        for (si.shape) |shape_coord| {
            const c = bc + (shape_coord orelse break);
            inventory[@intCast(c[0])][@intCast(c[1])] = si.id;
        }
        selected_item = null;
        return true;
    }
}
fn dropItem(si: *Item) void {
    if (si.pos) |old_pos| {
        for (si.shape) |shape_coord| {
            const c = old_pos + (shape_coord orelse @Vector(2, u8){ 0, 0 });
            inventory[@intCast(c[0])][@intCast(c[1])] = null;
        }
        si.pos = null;
    }
}
pub fn DrawItemMenu() void {
    const blk_tex = &assets.Texs.block;
    // darken the background
    rl.DrawRectangle(9, 9, conf.screenw, conf.screenh, rl.Color{ .r = 0, .b = 0, .g = 0, .a = 0x7f });
    // draw the grid

    for (0..bw) |x| {
        const xf: f32 = @floatFromInt(x);
        for (0..bh) |y| {
            const yf: f32 = @floatFromInt(y);
            const origin = blk_size * m.Vec2{ xf - (@as(f32, @floatFromInt(bw)) - 1) / 2, yf - (@as(f32, @floatFromInt(bh)) - 1) / 2 };
            utils.DrawTexture(blk_tex.*, origin, null, 0);
        }
    }
    // items come on top of grid
    for (0..bw) |x| {
        const xf: f32 = @floatFromInt(x);
        for (0..bh) |y| {
            const yf: f32 = @floatFromInt(y);
            const origin = m.Vec2{ blk_size[0], blk_size[1] } * m.Vec2{ xf - (@as(f32, @floatFromInt(bw)) - 1) / 2, yf - (@as(f32, @floatFromInt(bh)) - 1) / 2 };
            if (inventory[x][y]) |id| {
                const item = items.get(id) orelse unreachable;
                if (item.pos.?[0] == x and item.pos.?[1] == y) DrawItem(item, origin);
                // std.log.debug("draw item", .{})

            }
        }
    }
    var it = items.iterator();
    const list_x = -1.2;
    const list_y = -0.8;
    const list_h = 0.04;
    const list_w = 0.3;
    const list_space = 0.04;
    var list_ct: usize = 0;
    while (it.next()) |entry| : (list_ct += 1) {
        const item = entry.value_ptr;
        const ct: f32 = @floatFromInt(list_ct);
        rl.DrawRectangleV(m.coordn2srl(.{ list_x - 0.01, list_y + ct * list_space }), m.sizen2srl(.{ list_w, list_h }), rl.BEIGE);
        DrawText(.{ list_x, list_y + ct * list_space }, item.name, 20, rl.WHITE);
    }

    // draw the selected item

    const mouse_sv = rl.GetMousePosition();
    const mouse_v = m.srl2coord(mouse_sv);
    const mouse_list = @divFloor(mouse_v[1] - list_y, list_space);
    const mouse_list_i: isize = @intFromFloat(mouse_list);
    if (mouse_v[0] >= list_x and mouse_v[0] < list_x + list_w and mouse_list_i < list_ct and mouse_list_i >= 0) {
        const pos = m.coordn2srl(.{ list_x - 0.01, list_y + mouse_list * list_space });
        const size = m.sizen2srl(.{ list_w, list_h });
        rl.DrawRectangleLinesEx(.{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y }, 1, rl.WHITE);
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            it = items.iterator();
            list_ct = 0;
            selected_item = while (it.next()) |entry| : (list_ct += 1) {
                if (list_ct == mouse_list_i) break entry.value_ptr.id;
            } else unreachable;
        }
    }
    const bc: @Vector(2, i32) = @intFromFloat(mouse_v / blk_size + m.splat(2.5));
    if (selected_item) |id| {
        const si = items.getPtr(id) orelse unreachable;
        DrawItem(si.*, mouse_v);
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            if (!tryPlaceItem(bc, si)) {
                dropItem(si);
            }
            cal_item();
        }
    } else {
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT) and checkItemBound(bc)) {
            selected_item = inventory[@intCast(bc[0])][@intCast(bc[1])];
        }
    }

    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
        selected_item = null;
    }
}

pub fn cal_item() void {
    @panic("unimplemented");
}
