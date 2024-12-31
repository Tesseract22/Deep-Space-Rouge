const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const Assets = @import("assets.zig");
const m = @import("math.zig");
const conf = @import("config.zig");
const utils = @import("utils.zig");
const inventory = @import("inventory.zig");
const AnimationPlayer = Assets.AnimationPlayer;
const Animation = Assets.Animation;
const Vec2 = m.Vec2;
const Vec2i = m.Vec2i;
const Buff = comp.BuffHolder.Buff;
const esc = @import("esc_engine.zig");
const system = @import("system.zig");
const comp = @import("componet.zig");
const Entity = esc.Entity;
const syss = &system.syss;

const main = @import("main.zig");
const Weapon = comp.Weapon;
const ShootEffect = Weapon.ShootEffect;



const turret_impl = struct {
        pub fn shoot(
            weapon: *Weapon, effect: *ShootEffect, 
            vel: comp.Vel, ship_pos: comp.Pos, team: comp.Target,
            idx: isize) void 
        {
            const prev = weapon.get_effect(idx - 1) orelse return;
            const tex = &Assets.Texs.turret;
            const bullet = syss.new_entity();
            const turret_size = m.measure_tex(tex.*);
            const turret_vel = comp.Vel {.vel = vel.vel, .rot = vel.rot, .drag = 10, .rot_drag = 8};
            var turret_pos = ship_pos;
            turret_pos.roundabout = true;
            _ = prev;
            syss.add_comp(bullet, turret_pos);
            syss.add_comp(bullet, turret_vel);
            syss.add_comp(bullet, comp.View {.tex = tex, .size = turret_size});
            syss.add_comp(bullet, comp.Size.simple(turret_size[0] * 0.75));
            syss.add_comp(bullet, comp.Mass {.mass = turret_size[0] * turret_size[1] * 0.5});
            syss.add_comp(bullet, comp.ShipControl {.thurst = 0, .turn_thurst = 10});
            syss.add_comp(bullet, comp.Ai {.state = .{ .hunter = .{}}});
            { // make the new weapon
                var turret_weapon = weapon.clone();
                turret_weapon.clear_all_effects();
                turret_weapon.fire_rate = effect.data.turret.fire_rate * 0.75;
                turret_weapon.cool_down = 0.5;
                turret_weapon.bullet_spd *= 0.5;
                // turret_weapon.effects = comp.Weapon.ShootEffects.init(main.a);
                for (weapon.effects.keys(), weapon.effects.values(), 0..weapon.effects.count()) |id, e2, i| {
                    if (i == idx) break;
                    var e_copy = e2;
                    turret_weapon.append_effect(id, &e_copy);
                }
                syss.add_comp(bullet, turret_weapon);
            }
            // syss.add_comp(bullet, weapon.bullet);
            syss.add_comp(bullet, comp.CollisionSet1 {});
            syss.add_comp(bullet, comp.Health {.hp = 100, .max = 100, .regen = -2});
            syss.add_comp(bullet, comp.Target {.team = team.team, .prior = 10});

        }
        pub fn load(w: *Weapon, effect: *ShootEffect) void {
            effect.data.turret.fire_rate = w.fire_rate;
            effect.data.turret.bullet_spd = w.bullet_spd;
            w.fire_rate = 0.2;
        }
        pub fn un_load(w: *Weapon, effect: *ShootEffect) void {
            w.fire_rate = effect.data.turret.fire_rate;
            w.bullet_spd = effect.data.turret.bullet_spd;
        }

    };

pub var turret = comp.Weapon.ShootEffect {.shoot_fn = turret_impl.shoot, .data = .{.turret = undefined}, .on_load = turret_impl.load, .on_unload = turret_impl.un_load};

const triple_shot_impl = struct {
    pub fn shoot(
        weapon: *comp.Weapon, effect: *comp.Weapon.ShootEffect, 
        vel: comp.Vel, pos: comp.Pos, team: comp.Target,
        idx: isize) void 
    {
        _ = effect;
        const prev = weapon.get_effect(idx - 1) orelse return;
        var pos2 = pos;
        var vel2 = vel;
        prev.shoot_fn(weapon, prev, vel, pos, team, idx - 1);

        vel2.vel = m.v2rot(vel.vel, rl.PI / 12);
        pos2.rot = pos.rot + rl.PI / 12;
        prev.shoot_fn(weapon, prev, vel2, pos2, team, idx - 1);

        vel2.vel = m.v2rot(vel.vel, -rl.PI / 12);
        pos2.rot = pos.rot  - rl.PI / 12;
        prev.shoot_fn(weapon, prev, vel2, pos2, team, idx - 1);
    }
    pub fn load(w: *Weapon, effect: *ShootEffect) void {
        _ = effect;
        w.fire_rate /= 2;
    }
    pub fn un_load(w: *Weapon, effect: *ShootEffect) void {
        _ = effect;
        w.fire_rate *= 2;
    }
};
pub var triple_shot = ShootEffect {
    .data = undefined,
    .shoot_fn = triple_shot_impl.shoot,
    .on_load = triple_shot_impl.load,
    .on_unload = triple_shot_impl.un_load,
};


