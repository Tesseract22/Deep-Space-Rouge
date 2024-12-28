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
            } else {
                syss.del_comp(e, assets.AnimationPlayer);
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
                const size = (syss.comp_man.get_comp(comp.Size, e) orelse unreachable).size;

                var it2 = it;
                // _ = it2.next() orelse continue;
                while (it2.next()) |entry2| {
                    const e2 = entry2.*;
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

            @constCast(&entities[0]).unlockPointers();
            _ = dt;
            _ = self;
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
            //std.log.debug("elastic e: {}", .{e});
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const mass = (syss.comp_man.get_comp(comp.Mass, e) orelse unreachable).mass;
            const size = (syss.comp_man.get_comp(comp.Size, e) orelse unreachable).size;
            // _ = it2.next() orelse continue;
            const e2 = (syss.comp_man.get_comp(comp.Collision, e) orelse unreachable).other;
            //std.log.debug("elastic e: {}", .{e});
            // std.log.debug("collisio {} {}", .{e, e2});
            const mass2 = (syss.comp_man.get_comp(comp.Mass, e2) orelse continue).mass;
            const vel2 = syss.comp_man.get_comp(comp.Vel, e2) orelse continue;
            const pos2 = syss.comp_man.get_comp(comp.Pos, e2) orelse continue;
            const size2 = (syss.comp_man.get_comp(comp.Size, e2) orelse continue).size;


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
                // const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
                // if (health.dead) |dead_anim| {
                //     const anim_e = syss.new_entity();
                //     syss.add_comp(anim_e, pos.*);
                //     syss.add_comp(anim_e, assets.AnimationPlayer {.anim = dead_anim, .size = health.dead_size});
                //     if (syss.comp_man.get_comp(comp.Vel, e)) |vel| {
                //         syss.add_comp(anim_e, vel.*);
                //     }
                // }
                syss.add_comp(e, comp.Dead {});
            } else {
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
                        .sound = comp.GemDropper.Gem.Sounds[m.randGen.next() % comp.GemDropper.Gem.MAX_LEVEL],
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
        CompMan.sig_from_types(&.{comp.Weapon, comp.Pos, comp.ShipControl, comp.Team}),
        CompMan.sig_from_types(&.{comp.WeaponHolder, comp.Pos, comp.ShipControl, comp.Team}),
    };
    pub fn update_weapon(e: Entity, dt: f32, control: *comp.ShipControl, weapon: *comp.Weapon, team: *comp.Team, ship_pos: *comp.Pos) void {
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
            weapon.cool_down += 1 / weapon.fire_rate;
            if (len == 0) {
                // std.log.debug("here", .{});
                weapon.base_effect.shoot_fn(weapon, undefined, vel, pos, team.*, -1);
            } else {
                const effect = &weapon.effects.keys()[len - 1];
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
            const team = syss.comp_man.get_comp(comp.Team, e) orelse unreachable;
            const ship_pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;

            update_weapon(e, dt, control, weapon, team, ship_pos);

        }
        var it2 = entities[1].iterator();
        while (it2.next()) |entry| {
            const e = entry.key_ptr.*;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const weapon_holder = syss.comp_man.get_comp(comp.WeaponHolder, e) orelse unreachable;
            const team = syss.comp_man.get_comp(comp.Team, e) orelse unreachable;
            const ship_pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            var size: f32 = 0.1;
            if (syss.comp_man.get_comp(comp.Size, e)) |comp_size| {
                size = comp_size.size;
            }
            const gap = size / @as(f32, @floatFromInt(weapon_holder.weapons.items.len + 1));
            var pos = ship_pos.*;
            pos.pos = ship_pos.pos + m.v2rot(.{0, size/2 }, ship_pos.rot + rl.PI / 2);
            for (weapon_holder.weapons.items) |*weapon| {
                pos.pos -= m.v2rot(.{0, gap }, ship_pos.rot + rl.PI / 2);
                update_weapon(e, dt, control, weapon, team, &pos);
            }
        }
        _ = self;
    }

};



pub const Bullet = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.Bullet, comp.Collision, comp.Pos, comp.Team})};
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("elastic entities: {}", .{entities.count()});
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const bullet = syss.comp_man.get_comp(comp.Bullet, e) orelse unreachable;
            const collision = syss.comp_man.get_comp(comp.Collision, e) orelse unreachable;
            const team = syss.comp_man.get_comp(comp.Team, e) orelse unreachable;

            const health = syss.comp_man.get_comp(comp.Health, collision.other) orelse continue;
            const other_team = syss.comp_man.get_comp(comp.Team, collision.other) orelse continue;

            if (team.* == other_team.*) continue;
            health.hp -= bullet.dmg;

            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const anim_e = syss.new_entity();

            syss.add_comp(anim_e, pos.*);
            syss.add_comp(anim_e, assets.AnimationPlayer {.anim = &assets.Anims.bullet_hit});
            if (bullet.sound) |sound|
                rl.PlaySound(sound.*);
            if (bullet.penetrate == 0) syss.add_comp(e, comp.Dead {})
            else bullet.penetrate -= 1;
        }
        _ = dt;
        _ = self;
    }

};

pub const ShipAi = struct {
    pub const set = .{CompMan.sig_from_types(&.{comp.ShipControl, comp.Ai})};
    player: *Entity,
    pub fn update(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @alignCast(@ptrCast(ptr));
        // std.log.debug("Physic System update", .{});
        // std.log.debug("ai entities: {} {}", .{entities[0].count(), });
        var it = entities[0].iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const ai = syss.comp_man.get_comp(comp.Ai, e) orelse unreachable;

            control.reset_state();
            ai.ai(e, self.player.*, control);
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
