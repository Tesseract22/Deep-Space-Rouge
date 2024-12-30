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
const comp = @import("componet.zig");
const main = @import("main.zig");
const shoot_effect = @import("shoot_effect.zig");
const weapon = @import("weapon.zig");

const Weapon = comp.Weapon;
const ShootEffect = Weapon.ShootEffect;

const Self = @This();

pub fn spawn_item(self: *Self) void {

    const i = Item.item_weight[@as(usize, @intCast(m.randGen.next())) % Item.item_weight.len];
    const item = i[0]();
    // std.log.debug("spawned: {s}", .{item.name});
    _ = self.append_item(item);
    self.selected_item = item.id;
}

pub const Item = struct {
    pub var item_id: usize = 0;
    shape: [5]?@Vector(2, u8) = .{ .{ 0, 0 }, null, null, null, null },
    pos: ?@Vector(2, u8) = null,
    id: usize,
    tex: *rl.Texture2D,
    name: [:0]const u8,
    type: ItemType,

    const item_weight = [_]std.meta.Tuple(&[_]type{ (*const fn () Item), f32 }){
        // .{ Item.water, 1 },
        // .{ Item.weight, 1 },
        // .{ Item.energy_bullet, 1 },
        .{ Item.triple_shots, 1 },
        .{ Item.basic_gun, 1 },
        .{ Item.turret, 1},
        .{ Item.machine_gun, 1 },
    };

    const ItemType = union(enum) {
        weapon: comp.Weapon,
        effect: comp.Weapon.ShootEffect,
    };
    pub fn new_id() usize {
        defer item_id += 1;
        return item_id;
    }
    pub fn basic_gun() Item {
        return .{
            .id = new_id(), 
            .tex = &assets.Texs.weapon_1, 
            .name = "basic_gun", 
            .shape = .{ .{ 0, 0 }, .{ 0, 1 }, null, null, null },
            .type = .{.weapon = weapon.basic_gun()}};
    }
    pub fn triple_shots() Item {
        return .{
            .id = new_id(), 
            .tex = &assets.Texs.triple_shots, 
            .name = "triple shot", 
            .shape = .{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 }, null, null },
            .type = .{.effect = shoot_effect.triple_shot }};
    }
    pub fn machine_gun() Item {
        return .{
            .id = new_id(), 
            .tex = &assets.Texs.machine_gun, 
            .name = "machine gun", 
            .shape = .{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, null, null },
            .type = .{.weapon = weapon.machine_gun()}};

    }
    pub fn turret() Item {
        return .{
            .id = new_id(), 
            .tex = &assets.Texs.turret_item, 
            .name = "turret", 
            .shape = .{ .{ 0, 0 }, null, null, null, null },
            .type = .{.effect = shoot_effect.turret }
        };
    }
};

pub const bw = 5;
pub const bh = 5;
pub const blk_size = m.srl2sizen(.{ .x = 32 * conf.pixelMul, .y = 32 * conf.pixelMul });
const Items = std.AutoArrayHashMap(usize, Item);

inventory: [bh][bw]?usize = [_][bw]?usize{[_]?usize{null} ** bw} ** bh,
    items: Items,
    item_id: usize = 0,
    selected_item: ?usize = null,

    pub fn init(a: std.mem.Allocator) Self {
        return .{.items = Items.init(a)};
    }
pub fn deinit(self: *Self) void {
    var it = self.items.iterator();
    while (it.next()) |entry| {
        switch (entry.value_ptr.type) {
            .weapon => |*w| w.effects.deinit(),
            else => {},
        }
    }
    self.items.deinit();
}
pub fn append_item(self: *Self, item: Item) usize {
    self.items.put(item.id, item) catch unreachable;
    return item.id;
} 

fn DrawItem(item: Item, pos: m.Vec2) void {
    //  q
    const spos = m.coordn2srl(pos - blk_size / m.splat(2));
    rl.DrawTextureEx(item.tex.*, spos, 0, conf.pixelMul, rl.WHITE);
}
fn checkItemBound(bc: @Vector(2, i32)) bool {
    return bc[0] >= 0 and bc[1] >= 0 and bc[0] < bw and bc[1] < bh;
}
fn checkItemOccupied(self: Self, bc: @Vector(2, u8)) bool {
    return self.inventory[bc[0]][bc[1]] == null;
}
pub fn try_place_item(self: *Self, bc: @Vector(2, i32), id: usize) bool {
    const item = self.items.getPtr(id) orelse return false;
    return self.tryPlaceItem(bc, item);
}
fn tryPlaceItem(self: *Self, bc: @Vector(2, i32), si: *Item) bool {
    for (si.shape) |shape_coord| {
        const c = bc + (shape_coord orelse @Vector(2, u8){ 0, 0 });
        if (!checkItemBound(c) or !self.checkItemOccupied(@intCast(c))) {
            return false;
        }
    } else {
        self.drop_item(si);
        si.pos = .{ @intCast(bc[0]), @intCast(bc[1]) };
        for (si.shape) |shape_coord| {
            const c = bc + (shape_coord orelse break);
            self.inventory[@intCast(c[0])][@intCast(c[1])] = si.id;
        }
        self.selected_item = null;
        return true;
    }
}
fn drop_item(self: *Self, si: *Item) void {
    if (si.pos) |old_pos| {
        for (si.shape) |shape_coord| {
            const c = old_pos + (shape_coord orelse @Vector(2, u8){ 0, 0 });
            self.inventory[@intCast(c[0])][@intCast(c[1])] = null;
        }
        si.pos = null;
    }
}
pub fn draw(self: *Self) void {
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
            if (self.inventory[x][y]) |id| {
                const item = self.items.get(id) orelse unreachable;
                if (item.pos.?[0] == x and item.pos.?[1] == y) DrawItem(item, origin);
                // std.log.debug("draw item", .{})

            }
        }
    }
    var it = self.items.iterator();
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
        utils.DrawText(.{ list_x, list_y + ct * list_space }, item.name, 20, rl.WHITE);
    }


    // draw the selected item

    const mouse_sv = rl.GetMousePosition();
    const mouse_v = m.srl2coord(mouse_sv);
    const mouse_list = @divFloor(mouse_v[1] - list_y, list_space);
    const mouse_list_i: isize = @intFromFloat(mouse_list);
    const bc: @Vector(2, i32) = @intFromFloat(mouse_v / blk_size + m.splat(2.5));
    if (self.selected_item) |id| {
        const si = self.items.getPtr(id) orelse unreachable;
        DrawItem(si.*, mouse_v);
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            if (!self.tryPlaceItem(bc, si)) {
                self.drop_item(si);
            }
            self.cal_item();
        }
    } else if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT) and checkItemBound(bc)) {
        self.selected_item = self.inventory[@intCast(bc[0])][@intCast(bc[1])];
        if (self.selected_item) |selected| {
            const si = self.items.getPtr(selected) orelse unreachable;
            self.drop_item(si);
            self.cal_item();
        }
    }

    if (mouse_v[0] >= list_x and mouse_v[0] < list_x + list_w and mouse_list_i < list_ct and mouse_list_i >= 0) {
        const pos = m.coordn2srl(.{ list_x - 0.01, list_y + mouse_list * list_space });
        const size = m.sizen2srl(.{ list_w, list_h });
        rl.DrawRectangleLinesEx(.{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y }, 1, rl.WHITE);
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            it = self.items.iterator();
            list_ct = 0;
            self.selected_item = while (it.next()) |entry| : (list_ct += 1) {
                if (list_ct == mouse_list_i) {
                    rl.PlaySound(assets.Sounds.select);
                    break entry.value_ptr.id;
                }
            } else unreachable;
        }
    }


    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
        // if (self.selected_item)
        self.selected_item = null;
    }
}
pub fn neighbor(self: Self, item: *Item) Items {
    const V = @Vector(2, i32);
    var neighbors = Items.init(main.arena);
    for (item.shape) |shape_coord| {
        const bc: @Vector(2, i32) = @intCast((shape_coord orelse break) + item.pos.?);
        const neigh: [4]V = .{
            bc + V{ 1, 0 },
            bc + V{ -1, 0 },
            bc + V{ 0, 1 },
            bc + V{ 0, -1 },
        };
        for (neigh) |nc| {
            if (!checkItemBound(nc)) continue;
            const n: *Item = self.items.getPtr(self.inventory[@intCast(nc[0])][@intCast(nc[1])] orelse continue) orelse unreachable;
            if (n.id == item.id) continue;
            neighbors.put(n.id, n.*) catch unreachable;
        }
    }
    return neighbors;
}
pub fn cal_item(self: Self) void {
    const holder = sys.syss.comp_man.get_comp(comp.WeaponHolder, main.player) orelse @panic("Player doest not have a weapon holder");
    holder.weapons.resize(0) catch unreachable;

    var it = self.items.iterator();
    while (it.next()) |entry| {
        const item = entry.value_ptr;
        _ = item.pos orelse continue;
        switch (item.type) {
            .weapon => |*w| {
                w.clear_all_effects();
                var ns = self.neighbor(item);
                defer ns.deinit();
                // std.log.debug("neighbor {}", .{ns.count()});
                var it2 = ns.iterator();
                while (it2.next()) |entry2| {
                    const n = entry2.value_ptr;
                    switch (n.type) {
                        .effect => |*effect| {
                            w.append_effect(n.id, effect);
                        },
                        else => {},
                    }
                }
                holder.weapons.append(w.*) catch unreachable;
            },
            else => {},
        }
    }
}
