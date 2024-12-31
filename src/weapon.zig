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
        .bullet = .{.dmg = 10, .sound = &assets.Sounds.bullet_hit, .size = 0.1, .tex = &assets.Texs.bullet_2},
        .effects = comp.Weapon.ShootEffects.init(main.a),
        .spread = 0.1,
    };
}
