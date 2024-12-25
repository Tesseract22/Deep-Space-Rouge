const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const esc = @import("esc_engine.zig");
const Entity = esc.Entity;

const comp = @import("componet.zig");
const CompMan = comp.Manager;
const Signature = esc.Signature(&comp.comp_types);
const System = esc.System(&comp.comp_types);

const m = @import("math.zig");
const Vec2 = m.Vec2;

const conf = @import("config.zig");
const utils = @import("utils.zig");
const assets = @import("assets.zig");

pub const Manager = esc.SystemManager(&comp.comp_types, &comp.event_types);
pub var syss: Manager = undefined;

// ------------------------ System Implementation ------------------------
pub const Movement = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.Vel});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            vel.vel *= m.splat(1 - vel.drag * dt);
            vel.rot *= 1 - vel.rot_drag * dt;
            pos.pos += vel.vel * m.splat(dt);
            pos.rot += vel.rot;
            
            pos.pos = m.round_about(pos.pos);
            // std.log.debug("entity: {} {}", .{e, pos.pos});
        }
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};

pub const View = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.View});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const view = syss.comp_man.get_comp(comp.View, e) orelse unreachable;

            utils.DrawTexture(view.tex.*, pos.pos, view.size, pos.rot);
            // if (syss.comp_man.get_comp(comp.Size, e)) |size| {
            //     rl.DrawCircleLinesV(m.coordn2srl(pos.pos), m.size2s(size.size/2), rl.WHITE);
            // }
            // std.log.debug("entity: {} {} {}", .{e, pos.pos, view.radius});
        }
        _ = self;
        _ = dt;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};
pub const Animation = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, assets.AnimationPlayer});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const player = syss.comp_man.get_comp(assets.AnimationPlayer, e) orelse unreachable;

            if (player.play(dt)) |tex| {
                utils.DrawTexture(tex.*, pos.pos, null, pos.rot);
            } else {
                syss.del_comp(e, assets.AnimationPlayer);
            }
        }
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};

pub const Input = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Input, comp.ShipControl});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const input = syss.comp_man.get_comp(comp.Input, e) orelse unreachable;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            control.reset_state();
            const state = &control.state;
            const d = rl.IsKeyDown;

            if (d(input.left)) state.turn = .counter;
            if (d(input.right)) state.turn = .clock;
            if (d(input.forward)) state.forward = true;
            if (d(input.backward)) state.brake = true;
            // if (d(input.shoot)) state. = true;
        }
        _ = self;
        _ = dt;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};


pub const ShipControl = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.Vel, comp.ShipControl});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const state = &control.state;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const rot_acc: f32 = switch (state.turn) {
                .clock => 1,
                .counter => -1,
                .static => 0,
            };
            vel.rot += rot_acc * control.turn_thurst * dt;
            if (state.forward) {
                vel.vel += m.v2rot(m.up, pos.rot) * m.splat(control.thurst * dt);
            } else if (state.brake) {
                vel.vel *= m.splat(1 - control.brake_rate * dt);
            }
            // std.log.debug("entity: {} {}", .{e, pos.pos});
        }
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};
pub const Collision = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.Size});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        //std.log.debug("entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const size = (syss.comp_man.get_comp(comp.Size, e) orelse unreachable).size;


            var it2 = it;
            // _ = it2.next() orelse continue;
            while (it2.next()) |entry2| {
                const e2 = entry2.key_ptr.*;
                // std.log.debug("collisio {} {}", .{e, e2});
                const pos2 = syss.comp_man.get_comp(comp.Pos, e2) orelse unreachable;
                const size2 = (syss.comp_man.get_comp(comp.Size, e2) orelse unreachable).size;

                const dist = m.v2dist(pos.pos, pos2.pos);
                if (dist < (size + size2) / 2) {
                    syss.add_comp(e, comp.Collision {.other = e2});
                    syss.add_comp(e2, comp.Collision {.other = e});
                }
            }

        }
        _ = dt;
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};


pub const Elastic = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.Vel, comp.Mass, comp.Size, comp.Collision});
    const elastic = 0.6;
    pub const collision_dmg_mul = 50;
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const mass = (syss.comp_man.get_comp(comp.Mass, e) orelse unreachable).mass;
            const size = (syss.comp_man.get_comp(comp.Size, e) orelse unreachable).size;
            // _ = it2.next() orelse continue;
            const e2 = (syss.comp_man.get_comp(comp.Collision, e) orelse unreachable).other;
            // std.log.debug("collisio {} {}", .{e, e2});
            const vel2 = syss.comp_man.get_comp(comp.Vel, e2) orelse unreachable;
            const pos2 = syss.comp_man.get_comp(comp.Pos, e2) orelse unreachable;
            const mass2 = (syss.comp_man.get_comp(comp.Mass, e2) orelse unreachable).mass;
            const size2 = (syss.comp_man.get_comp(comp.Size, e2) orelse unreachable).size;


            const dist = m.v2dist(pos.pos, pos2.pos);
            const total_m = mass + mass2;
            const wx = mass2 / total_m;
            // const wy = mass / total_m;
            const d = m.v2n(pos.pos - pos2.pos);
            const xs = m.v2dot(vel.vel, d);
            const ys = m.v2dot(vel2.vel, d);
            const s = xs - ys;
            if (s >= 0) continue;
            // rl.PlaySound(Assets.Sounds.collide);
            // if (dmg) {
            //     y.hp -= wy * (-s) * 10;
            //     x.hp -= wx * (-s) * 10;
            // }

            vel.vel -= m.splat(wx * (1 + elastic) * s) * d;
            // vel2.vel += m.splat(wy * (1 + elastic) * s) * d;

            const diff = (size + size2) / 2 - dist;
            pos.pos += m.splat(0.5 * diff) * d;

            if (syss.comp_man.get_comp(comp.Health, e)) |health| {
                health.hp -= -s * wx * collision_dmg_mul;
            }
            // pos2.pos -= m.splat(0.5 * diff) * d;

        }
        _ = dt;
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};

pub const Health = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Health, comp.Pos});
    player_e: esc.Entity,
    player_dead: bool = false,
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const health = syss.comp_man.get_comp(comp.Health, e) orelse unreachable;
            if (health.hp <= 0) {
                const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
                if (health.dead) |dead_anim| {
                    const anim_e = syss.new_entity();
                    syss.add_comp(anim_e, pos.*);
                    syss.add_comp(anim_e, assets.AnimationPlayer {.anim = dead_anim});
                }
                syss.free_entity(e);
                if (self.player_e == e) self.player_dead = true;
            } else {
                health.hp += health.regen;
            }
        }
        _ = dt;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};


