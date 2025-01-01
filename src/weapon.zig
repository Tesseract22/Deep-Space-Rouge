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

const Weapon = comp.Weapon;
const ShootEffect = Weapon.ShootEffect;


pub fn basic_gun() Weapon {
    return Weapon {
        .fire_rate = 5, 
        .sound = &assets.Sounds.shoot, 
        .bullet = .{ .dmg = 30, .sound = &assets.Sounds.bullet_hit, .tex = &assets.Texs.bullet, .size = 0.10, },
        .effects = comp.Weapon.ShootEffects.init(main.a),
    };
}

pub fn machine_gun() Weapon {
    return Weapon {
        .cool_down = 0,
        .fire_rate = 10, 
        .bullet_spd = 2,
        .sound = &assets.Sounds.shoot2, 
        .bullet = .{.dmg = 10, .sound = &assets.Sounds.bullet_hit, .size = 0.05, .tex = &assets.Texs.bullet_2},
        .effects = comp.Weapon.ShootEffects.init(main.a),
        .spread = 0.1,
    };
}
const Vel = comp.Vel;
const Pos = comp.Pos;
const Target = comp.Target;
const View = comp.View;
const Size = comp.Size;
pub fn torpedo() Weapon {
    const impl = struct {
        pub fn shoot(
            weapon: *Weapon, effect: *ShootEffect, 
            vel: Vel, pos: Pos, team: Target,
            idx: isize) void 
        {
            _ = effect;
            _ = idx;
            const bullet = sys.syss.new_entity();
            sys.syss.add_comp(bullet, pos);
            sys.syss.add_comp(bullet, vel);
            if (weapon.bullet.tex) |tex| sys.syss.add_comp(bullet, View {.tex = tex, .size = m.splat(weapon.bullet.size)});
            sys.syss.add_comp(bullet, Size.simple(weapon.bullet.size));
            sys.syss.add_comp(bullet, weapon.bullet);
            sys.syss.add_comp(bullet, comp.CollisionSet1 {});
            sys.syss.add_comp(bullet, team);
            sys.syss.add_comp(bullet, comp.ShipControl {.state = .{.forward = true}, .thurst = 3});
        }
    };
    const size = m.measure_tex(assets.Texs.missile);
    return Weapon {
        .cool_down = 0,
        .fire_rate = 2, 
        .bullet_spd = 0.5,
        .sound = &assets.Sounds.shoot2, 
        .bullet = .{.dmg = 90, .sound = &assets.Sounds.bullet_hit, .size = size[0] * 1.2, .tex = &assets.Texs.missile, .area = 0.5, .penetrate = 0},
        .effects = comp.Weapon.ShootEffects.init(main.a),
        .spread = 0.1,
        .base_effect = .{.data = undefined, .shoot_fn = impl.shoot}
    };
}
