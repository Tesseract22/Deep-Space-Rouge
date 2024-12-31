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
const main = @import("main.zig");
const enemy = @import("enemy.zig");

pub const Manager = esc.SystemManager(&comp.comp_types, &comp.event_types);
pub var syss: Manager = undefined;

// generic function for creating an esc.System interface from an System Implementation
pub fn get(self: anytype, a: Allocator) System {
    const T = @TypeOf(self.*);
    const entities = a.alloc(std.AutoHashMap(Entity, void), T.set.len) catch unreachable;
    for (entities) |*es| {
        es.* = std.AutoHashMap(Entity, void).init(a);
    }
    return .{
        .entities = entities,
        .ptr = @alignCast(@ptrCast(self)),
        .update_fn = T.update,
        .set = &T.set,
    };
}
// ------------------------ System Implementation ------------------------
pub const Movement = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Pos, comp.Vel})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            vel.vel *= m.splat(1 - vel.drag * dt);
            vel.rot *= 1 - vel.rot_drag * dt;
            pos.pos += vel.vel * m.splat(dt);
            pos.rot += vel.rot * dt;
            pos.rot = @mod(pos.rot, 2 * rl.PI);
            // if (e == main.player) {
            //     std.log.debug("player pos {}", .{pos.pos});
            // }
            if (pos.roundabout)
                pos.pos = m.round_about(pos.pos);
            // std.log.debug("entity: {} {}", .{e, pos.pos});
            if (@abs(pos.pos[0]) > 3 or @abs(pos.pos[1]) > 3)
                syss.free_entity(e);
        }
        _ = self;
    }
};




pub const View = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Pos, comp.View})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const view = syss.comp_man.get_comp(comp.View, e) orelse unreachable;

            utils.DrawTextureTint(view.tex.*, pos.pos, view.size, pos.rot, view.tint);
            // if (syss.comp_man.get_comp(comp.Size, e)) |cs| {

            //     for (cs.cs) |c| {
            //         rl.DrawCircleLinesV(m.coordn2srl(pos.pos + m.v2rot(c.pos, pos.rot)), m.size2s(c.size/2), rl.WHITE);
            //     }
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
            .set = &set,
        };
    }
};
pub const Animation = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Pos, assets.AnimationPlayer})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const player = syss.comp_man.get_comp(assets.AnimationPlayer, e) orelse unreachable;

            if (player.play(dt)) |tex| {
                utils.DrawTexture(tex.*, pos.pos, player.size, pos.rot);
            } else if (player.should_kill) {
                syss.add_comp(e, comp.Dead{});
            }
        }
        _ = self;
    }
};

pub const Input = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Input, comp.ShipControl, comp.Pos})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const input = syss.comp_man.get_comp(comp.Input, e) orelse unreachable;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;

            control.reset_state();
            const state = &control.state;
            const d = rl.IsKeyDown;

            const mouse_pos = m.srl2coord(rl.GetMousePosition());
            if (!input.mouse) {
                if (d(input.left)) state.turn = .counter;
                if (d(input.right)) state.turn = .clock;
                if (d(input.forward)) state.forward = true;
            } else {
                if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_RIGHT))
                    control.turn_to_pos(pos.*, mouse_pos);
                if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) 
                    state.forward = true;
            }
            if (d(input.backward)) state.brake = true;
            if (d(input.shoot)) state.shoot = true;
            if (d(input.dash)) state.dash = true;
        }
        _ = self;
        _ = dt;
    }

};


pub const ShipControl = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Pos, comp.Vel, comp.ShipControl})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("entities: {}", .{entities.count()});
        var it = entities[0].iterator();
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
                if (control.thurst_anim) |*anim| {
                    const thurst_pos = pos.pos - m.v2rot(m.up, pos.rot) * m.splat(0.175);
                    const tex = anim.play(dt) orelse unreachable;
                    utils.DrawTexture(tex.*, thurst_pos, null, pos.rot);
                }
            } else if (state.brake) {
                vel.vel *= m.splat(1 - control.brake_rate * dt);
            }
            if (state.dash_cd > 0) {
                state.dash_cd -= dt;
            }
            if (state.dash_cd <= 0 and state.dash) {
                vel.vel += m.v2rot(m.up, pos.rot) * m.splat(control.dash_thurst);
                state.dash_cd += control.dash_cd;
            }
            // std.log.debug("entity: {} {}", .{e, pos.pos});
        }
        _ = self;
    }
    
};
pub fn Collision(comptime Set: type) type {
    return struct {
        pub const set = .{CompMan.sig_from_types(&.{comp.Pos, comp.Size, Set})};
        pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
            const self: *@This() = @ptrCast(ptr);
            // std.log.debug("Physic System update", .{});
            // std.log.debug("entities: {}", .{entities.count()});
            var it = entities[0].keyIterator();
            @constCast(&entities[0]).lockPointers();
            while (it.next()) |entry| {
                const e = entry.*;
                const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
                const size = (syss.comp_man.get_comp(comp.Size, e) orelse unreachable);

                var it2 = it;
                // _ = it2.next() orelse continue;
                while (it2.next()) |entry2| {
                    const e2 = entry2.*;
                    // std.log.debug("collisio {} {}", .{e, e2});
                    const pos2 = syss.comp_man.get_comp(comp.Pos, e2) orelse unreachable;
                    const size2 = (syss.comp_man.get_comp(comp.Size, e2) orelse unreachable);
                    outer: for (size.cs, 0..) |c1, j1| {
                        if (c1.size == 0) break :outer;
                        for (size2.cs, 0..) |c2, j2| {
                            if (c2.size == 0) break :outer;
                            const dist = m.v2dist(m.v2rot(c1.pos, pos.rot) + pos.pos, m.v2rot(c2.pos, pos2.rot) + pos2.pos);
                            if (dist < (c1.size + c2.size) / 2) {
                                generate_collision_event(e, e2, j1, j2);
                                generate_collision_event(e2, e, j2, j1);
                                break :outer;
                            }
                        }
                    }
                }

            }
            @constCast(&entities[0]).unlockPointers();
            _ = dt;
            _ = self;
        }
        pub fn generate_collision_event(e1: Entity, e2: Entity, my_sub: usize, other_sub: usize) void {
            if (syss.get_comp(e1, comp.Collision)) |coll| {
                coll.others.append(.{.e = e2, .my_sub = @intCast(my_sub), .other_sub = @intCast(other_sub)}) catch {}; // more collisions are simply ignored, for now
            } else {
                var coll = comp.Collision {};
                coll.others.append(.{.e = e2, .my_sub = @intCast(my_sub), .other_sub = @intCast(other_sub)}) catch unreachable;
                syss.add_comp(e1, coll);
            }

        }

    };

}


pub const Elastic = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Pos, comp.Vel, comp.Mass, comp.Size, comp.Collision})};
    const elastic = 0.6;
    pub const collision_dmg_mul = 5;
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities[0].count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            // std.log.debug("elastic e: {}", .{e});
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const mass = (syss.comp_man.get_comp(comp.Mass, e) orelse unreachable).mass;
            // _ = it2.next() orelse continue;

            const collisions = syss.comp_man.get_comp(comp.Collision, e) orelse unreachable;
            for (collisions.others.constSlice()) |coll| {

                const c1 = (syss.comp_man.get_comp(comp.Size, e) orelse unreachable).cs[coll.my_sub];
                //std.log.debug("elastic e: {}", .{e});
                // std.log.debug("collisio {} {}", .{e, e2});
                const e2 = coll.e;
                const mass2 = (syss.comp_man.get_comp(comp.Mass, e2) orelse continue).mass;
                const vel2 = syss.comp_man.get_comp(comp.Vel, e2) orelse continue;
                const pos2 = syss.comp_man.get_comp(comp.Pos, e2) orelse continue;
                const c2 = (syss.comp_man.get_comp(comp.Size, e2) orelse continue).cs[coll.other_sub];


                const dist = m.v2dist(pos.pos, pos2.pos);
                const total_m = mass + mass2;
                const wx = mass2 / total_m;
                // const wy = mass / total_m;
                const d = if (dist == 0) 
                    m.Vec2 {m.randSign() * m.randf(0.0001, 0.001), m.randSign() * m.randf(0.0001, 0.001)} 
                else 
                    m.v2n(pos.pos - pos2.pos);
                const xs = m.v2dot(vel.vel, d);
                const ys = m.v2dot(vel2.vel, d);
                const s = xs - ys;
                // rl.PlaySound(Assets.Sounds.collide);
                // if (dmg) {
                //     y.hp -= wy * (-s) * 10;
                //     x.hp -= wx * (-s) * 10;
                // }
                // std.log.debug("elastic e: {}", .{e});
                // vel2.vel += m.splat(wy * (1 + elastic) * s) * d;
                const diff = (c1.size + c2.size) / 2 - m.v2dist(pos.pos + m.v2rot(c1.pos, pos.rot), pos2.pos + m.v2rot(c2.pos, pos2.rot));
                pos.pos += m.splat(wx * diff) * d;
                // _ = diff;
                if (s >= 0) continue;
                vel.vel -= m.splat(wx * (1 + elastic) * s) * d;


                if (syss.comp_man.get_comp(comp.Health, e)) |health| {
                    health.hp -= -s * wx * collision_dmg_mul;
                }
                // pos2.pos -= m.splat(0.5 * diff) * d;
            }
        }
        _ = dt;
        _ = self;
    }

};

pub const Health = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Health, comp.Pos})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const health = syss.comp_man.get_comp(comp.Health, e) orelse unreachable;
            if (health.hp <= 0) {
                rl.PlaySound(assets.Sounds.hurt);
                syss.add_comp(e, comp.Dead {});
            } else if (health.hp < health.max) {
                health.hp += health.regen * dt;
            }
        }
        _ = self;
    }

};

pub const Dead = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Dead})};
    player_e: *esc.Entity,
    player_dead: bool = false,
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            syss.free_entity(e);
            if (self.player_e.* == e) self.player_dead = true;
        }
        _ = dt;
    }

};

pub const DeadAnimation = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Dead, comp.DeadAnimation, comp.Pos})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const anim = syss.comp_man.get_comp(comp.DeadAnimation, e) orelse unreachable;
            const anim_e = syss.new_entity();
            syss.add_comp(anim_e, pos.*);
            syss.add_comp(anim_e, assets.AnimationPlayer {.anim = anim.dead, .size = anim.dead_size});
            if (syss.comp_man.get_comp(comp.Vel, e)) |vel| {
                syss.add_comp(anim_e, vel.*);
            }

        }
        _ = self;
        _ = dt;
    }

};


pub const GemDropper = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Dead, comp.GemDropper, comp.Pos})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const dropper = syss.comp_man.get_comp(comp.GemDropper, e) orelse unreachable;


            var left = dropper.value;
            var cts = [_]usize{0} ** 3;
            for (0..3) |i| {
                const ri = 3 - i - 1;
                cts[ri] = left / comp.GemDropper.Gem.Worths[ri];
                left -= cts[ri] * comp.GemDropper.Gem.Worths[ri];
            }
            var gem_pos = pos.*;
            gem_pos.roundabout = true;
            for (cts, 0..) |ct, lvl| {
                for (0..ct) |_| {
                    const g = syss.new_entity();
                    syss.add_comp(g, gem_pos);
                    syss.add_comp(g, comp.Vel {
                        .vel = .{ m.randf(-0.2, 0.2), m.randf(-0.2, 0.2) },
                        .rot = m.randf(-0.1, 0.1),
                        .drag = 1,
                        .rot_drag = 0.1,
                    });
                    syss.add_comp(g, comp.View {.tex = comp.GemDropper.Gem.Texs[lvl]});
                    syss.add_comp(g, comp.Collectible {
                        .collect_radius = 0.1, 
                        .attract_radius = 0.2, 
                        .sound = comp.GemDropper.Gem.Sounds[@as(usize, @intCast(m.randGen.next())) % comp.GemDropper.Gem.MAX_LEVEL],
                        .data = .{.gem = .{.level = @intCast(lvl)}},
                    });
                    // g.lvl = @intCast(lvl);
                    //
                }
            }
        }
        _ = self;
        _ = dt;
    }

};



pub const Weapon = struct {
    pub const set = .{
        CompMan.sig_from_types(&.{comp.Weapon, comp.Pos, comp.ShipControl, comp.Target}),
        CompMan.sig_from_types(&.{comp.WeaponHolder, comp.Pos, comp.ShipControl, comp.Target}),
    };
    pub fn update_weapon(holder: ?*comp.WeaponHolder, e: Entity, dt: f32, control: *comp.ShipControl, weapon: *comp.Weapon, team: *comp.Target, ship_pos: *comp.Pos) void {
        const holder_default = comp.WeaponHolder {.weapons = undefined};
        const holder_actual = holder orelse &holder_default;
        if (weapon.cool_down > 0) {
            weapon.cool_down -= dt;
        }
        if (!control.state.shoot) return;

        const default_vel = comp.Vel {};
        const ship_vel = syss.comp_man.get_comp(comp.Vel, e) orelse &default_vel;

        var pos = ship_pos.*;
        pos.roundabout = false;
        pos.pos += m.v2rot(m.up, pos.rot + m.randf(-weapon.spread, weapon.spread)) * m.splat(0.1);
        var vel = comp.Vel {};
        vel.vel = ship_vel.vel + m.v2rot(m.up, pos.rot) * m.splat(weapon.bullet_spd);
        vel.vel = m.v2rot(vel.vel, m.randf(-weapon.spread, weapon.spread));
        const len = weapon.effects.count();
        while (weapon.cool_down <= 0) {
            weapon.cool_down += 1 / (weapon.fire_rate * holder_actual.fire_rate) ;
            if (len == 0) {
                // std.log.debug("here", .{});
                weapon.base_effect.shoot_fn(weapon, undefined, vel, pos, team.*, -1);
            } else {
                const effect = &weapon.effects.values()[len - 1];
                effect.shoot_fn(weapon, effect, vel, pos, team.*, @intCast(len - 1));
            }
            if (weapon.sound) |sound|
                rl.PlaySound(sound.*);

        }

    }
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("Weapon entities: {}", .{entities[0].count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const weapon = syss.comp_man.get_comp(comp.Weapon, e) orelse unreachable;
            const team = syss.comp_man.get_comp(comp.Target, e) orelse unreachable;
            const ship_pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;

            update_weapon(null, e, dt, control, weapon, team, ship_pos);

        }
        var it2 = entities[1].iterator();
        while (it2.next()) |entry| {
            const e = entry.key_ptr.*;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const weapon_holder = syss.comp_man.get_comp(comp.WeaponHolder, e) orelse unreachable;
            const team = syss.comp_man.get_comp(comp.Target, e) orelse unreachable;
            const ship_pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            var size: f32 = 0.1;
            if (syss.comp_man.get_comp(comp.Size, e)) |comp_size| {
                size = comp_size.cs[0].size;
            }
            const gap = size / @as(f32, @floatFromInt(weapon_holder.weapons.items.len + 1));
            var pos = ship_pos.*;
            pos.pos = ship_pos.pos + m.v2rot(.{0, size/2 }, ship_pos.rot + rl.PI / 2);
            for (weapon_holder.weapons.items) |*weapon| {
                pos.pos -= m.v2rot(.{0, gap }, ship_pos.rot + rl.PI / 2);
                update_weapon(weapon_holder, e, dt, control, weapon, team, &pos);
            }
        }
        _ = self;
    }

};



pub const Bullet = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Bullet, comp.Collision, comp.Pos, comp.Target})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const bullet = syss.comp_man.get_comp(comp.Bullet, e) orelse unreachable;
            const collision = syss.comp_man.get_comp(comp.Collision, e) orelse unreachable;
            const team = syss.comp_man.get_comp(comp.Target, e) orelse unreachable;

            for (collision.others.constSlice()) |coll| {
                const other = coll.e;
                const health = syss.comp_man.get_comp(comp.Health, other) orelse continue;
                const other_team = syss.comp_man.get_comp(comp.Target, other) orelse continue;
                const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;

                if (team.team == other_team.team) continue;
                if (bullet.area != 0) {
                    const explode = syss.new_entity();
                    syss.add_comp(explode, pos.*);
                    syss.add_comp(explode, comp.Bullet {.area = 0, .size = bullet.area, .dmg = bullet.dmg, .tex = null});
                    syss.add_comp(explode, comp.Size.simple(bullet.area));
                    syss.add_comp(explode, comp.CollisionSet1{});
                    syss.add_comp(explode, team.*);
                } else {
                    health.hp -= bullet.dmg;
                }

                
                const anim_e = syss.new_entity();
                syss.add_comp(anim_e, pos.*);
                if (bullet.area == 0) 
                    syss.add_comp(anim_e, assets.AnimationPlayer {.anim = &assets.Anims.bullet_hit})
                else 
                    syss.add_comp(anim_e, assets.AnimationPlayer {.anim = &assets.Anims.explode_blue, .size = m.splat(bullet.area/2)});
                if (bullet.sound) |sound|
                    rl.PlaySound(sound.*);
                if (bullet.penetrate == 0) syss.add_comp(e, comp.Dead {})
                else bullet.penetrate -= 1;
            }
        }
        _ = dt;
        _ = self;
    }

};

pub const ShipAi = struct {
    pub const set = .{
        CompMan.sig_from_types(&.{comp.ShipControl, comp.Ai}),
        CompMan.sig_from_types(&.{comp.Health, comp.Target}),
    };
    const TEAM_LEN = comp.Target.TEAM_LEN;
    const TargetQueue = comp.Ai.TargetQueue;
    targets: [TEAM_LEN]TargetQueue,
    pub fn init() ShipAi {
        var ai = ShipAi {.targets = undefined};
        for (0..TEAM_LEN) |t| {
            ai.targets[t] = TargetQueue.init(main.a, void {});
        }
        return ai;
    } 
    pub fn deinit(self: *ShipAi) void {
        for (0..TEAM_LEN) |t| {
            self.targets[t].deinit();
        }
    }
    // TargetQueue.peek

    // enemy_enemy: std.PriorityQueue
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("ai entities: {} {}", .{entities[0].count(), });
        var it2 = entities[1].iterator();
        while (it2.next()) |entry| {
            const e = entry.key_ptr.*;
            const target = syss.comp_man.get_comp(comp.Target, e) orelse unreachable;
            self.targets[@intFromEnum(target.team)].add(.{.target = target.*, .e = e}) catch unreachable;
        }
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const ai = syss.comp_man.get_comp(comp.Ai, e) orelse unreachable;

            control.reset_state();
            ai.ai(e, &self.targets, control);
        }
        for (&self.targets) |*target| {
            // FIXME find a way to clear and retain capacity
            target.deinit();
            target.* = TargetQueue.init(main.a, void{});
        }

        _ = dt;
    }
};

pub const Collector = struct {
    pub const set = .{
        CompMan.sig_from_types(&.{comp.Collector, comp.Pos}), 
        CompMan.sig_from_types(&.{comp.Collectible, comp.Pos, comp.Vel})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        //std.log.debug("collector entities: {}", .{entities[0].count(), });
        // std.log.debug("collectible entities: {}", .{entities[1].count(), });
        var it_tor = entities[0].keyIterator();
        var it_tee = entities[1].keyIterator();
        while (it_tor.next()) |entry| {
            const e_tor = entry.*;
            const pos1 = syss.comp_man.get_comp(comp.Pos, e_tor) orelse unreachable;
            const collector = syss.comp_man.get_comp(comp.Collector, e_tor) orelse unreachable;
            while (it_tee.next()) |entry2| {
                const e_tee = entry2.*;
                const pos2 = syss.comp_man.get_comp(comp.Pos, e_tee) orelse unreachable;
                const collectible = syss.comp_man.get_comp(comp.Collectible, e_tee) orelse unreachable;
                const vel = syss.comp_man.get_comp(comp.Vel, e_tee) orelse unreachable;
                const dist = m.v2dist(pos1.pos, pos2.pos);
                // std.log.debug("dist {}", .{dist});
                if (dist <= collector.collect_radius + collectible.collect_radius) {
                    syss.add_comp(e_tee, comp.Dead{});
                    rl.PlaySound(collectible.sound.*);
                    collectible.effect(e_tee, e_tor);
                } else if (dist <= collector.attract_radius + collectible.attract_radius) {
                    vel.vel += m.v2n(pos1.pos - pos2.pos) * m.splat(collectible.attract_pull * dt);
                }
            }
        }
        _ = self;
    }
};

pub const Buff = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.BuffHolder})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        //std.log.debug("collector entities: {}", .{entities[0].count(), });
        // std.log.debug("collectible entities: {}", .{entities[1].count(), });
        var it = entities[0].keyIterator();
        while (it.next()) |entry| {
            const e = entry.*;
            const buffs = syss.comp_man.get_comp(comp.BuffHolder, e) orelse unreachable;

            var i: usize = 0;
            while (i < buffs.buffs.items.len) {
                const buff = &buffs.buffs.items[i];
                if (buff.fresh) {
                    buff.apply(buff, e);
                    buff.fresh = false;
                }
                if (buff.duration <= 0) {
                    buff.expire(buff, e);
                    _ = buffs.buffs.swapRemove(i);
                } else  {
                    buff.duration -= dt;
                    i += 1;
                }
            }
        }
        _ = self;
    }
    pub fn try_apply(e: esc.Entity, new_buff: *comp.BuffHolder.Buff) void {
        const holder = syss.comp_man.get_comp(comp.BuffHolder, e) orelse return;
        holder.buffs.append(new_buff.*) catch unreachable;
    }
};

pub const EnemeySpawner = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Dead})};
    const SpawnFn = fn (pos: comp.Pos) esc.Entity;
    const enemy_weights = [_]std.meta.Tuple(&[_]type{ *const SpawnFn, usize }){ 
        .{ enemy.spawn_crasher, 9 }, 
        .{ enemy.spawn_hunter, 30 },
        .{ enemy.spawn_carrier, 60 }, 

    };
    const wave_cd = 2.0;
    const wormhole_teleport_t = 3;
    const WormHoleTimer = struct {
        control: comp.ShipControl,
        mass: comp.Mass,
        mature: bool = false,
    };

    wave: std.AutoHashMap(esc.Entity, WormHoleTimer),
    mature_ct: usize = 0,
    wave_worth: usize = 100,
    wave_ct: usize = 0,
    t: f32 = wave_cd,
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        var it = entities[0].keyIterator();
        while (it.next()) |entry| {
            const e = entry.*;
            _ = self.wave.remove(e);
        }
        var it2 = self.wave.iterator();
        if (self.mature_ct < self.wave.count()) {
            while (it2.next()) |entry| {
                const e = entry.key_ptr.*;
                const timer = entry.value_ptr;
                if (timer.mature) continue;
                const anim_player = syss.comp_man.get_comp(assets.AnimationPlayer, e) orelse unreachable;
                const view = syss.comp_man.get_comp(comp.View, e) orelse unreachable;
                const ratio = @as(f32, @floatFromInt(anim_player.curr_frame)) / @as(f32, @floatFromInt(anim_player.anim.frames.items.len));
                view.tint.a = @intFromFloat(ratio * ratio * 255);
                if (anim_player.isLast()) {
                    syss.add_comp(e, timer.control);
                    syss.add_comp(e, timer.mass);
                    timer.mature = true;
                    self.mature_ct += 1;
                    view.tint.a = 255;
                }
            }
        }
        if (self.wave.count() == 0) {
            if (self.t <= 0) {
                self.spawn_wave();
                self.t = wave_cd; 
                self.mature_ct = 0;
            } else {
                self.t -= dt;
            }
        }
    }
    fn spawn_wave(self: *EnemeySpawner) void {
        main.Annouce("New Wave!", 2);

        var total: usize = 0;
        while (total < self.wave_worth) {
            const t = enemy_weights[@as(usize, @intCast(m.randGen.next())) % enemy_weights.len];
            const max_t: usize = @max((self.wave_worth - total) / t[1], 1);
            const n: usize = m.randu(1, max_t);
            for (0..n) |_| {
                const pos = comp.Pos {.pos = m.rand_pos(), .rot = m.rand_rot(), .roundabout = false};
                const e = t[0](pos);
                syss.add_comp(e, assets.AnimationPlayer {.anim = &assets.Anims.wormhole, .should_kill = false});
                // temporarily remove some component while the wormhole is warping
                const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
                const mass = syss.comp_man.get_comp(comp.Mass, e) orelse unreachable;
                syss.del_comp(e, comp.ShipControl);
                syss.del_comp(e, comp.Mass);
                self.wave.put(e, .{.control = control.*, .mass = mass.*}) catch unreachable;
            }
            total += n * t[1];
        }
        self.wave_worth += 75;
        self.wave_ct += 1;
        const asteriod_ct = m.randu(0, 5);
        for (0..asteriod_ct) |_| {
            _ = main.spawn_asteriod();
        }
        // spawn some asteriods
    }
    pub fn init(a: Allocator) EnemeySpawner {
        return .{.wave = std.AutoHashMap(esc.Entity, WormHoleTimer).init(a)};
    }
    pub fn deinit(self: *EnemeySpawner) void {
        self.wave.deinit();
    }

};


