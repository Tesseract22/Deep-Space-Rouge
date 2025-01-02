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
const weapon = @import("weapon.zig");

const main = @import("main.zig");
const Weapon = comp.Weapon;
const ShootEffect = Weapon.ShootEffect;


const shoot_effect = @import("shoot_effect.zig");


pub fn spawn_hunter(pos: comp.Pos) Entity {
    const e: Entity = syss.new_entity();
    const size = m.measure_tex(Assets.Texs.hunter);
    syss.add_comp(e, pos);
    syss.add_comp(e, comp.Vel {
        .drag = 2,
        .rot_drag = 8,
    });
    syss.add_comp(e, comp.View { 
        .tex = &Assets.Texs.hunter, 
        .size = size,
    });
    syss.add_comp(e, comp.ShipControl {
        .thurst = 1.5,
        .turn_thurst = 12,
    });
    syss.add_comp(e, comp.Size.simple(size[0]));
    syss.add_comp(e, comp.Mass {.mass = size[0] * size[1]});
    syss.add_comp(e, comp.Health {.hp = 100, .max = 100, });
    syss.add_comp(e, comp.DeadAnimation { .dead = &Assets.Anims.explode_blue});
    const weapon_comp = comp.Weapon {
        .cool_down = 2,
        .fire_rate = 0.5, 
        .bullet_spd = 1,
        .sound = &Assets.Sounds.shoot, 
        .bullet = .{
            .dmg = 35, .sound = &Assets.Sounds.bullet_hit, .size = 0.1, .tex = &Assets.Texs.bullet_fire, .particle_color = rl.ORANGE
        },
        .effects = comp.Weapon.ShootEffects.init(main.a),
    };
    // weapon_comp.effects.put(comp.Weapon.ShootEffect {.shoot_fn = triple_shot.shoot, .data = undefined}, void{}) catch unreachable;
    syss.add_comp(e, weapon_comp);
    syss.add_comp(e, comp.Ai {.state = .{ .hunter = .{}}});
    syss.add_comp(e, comp.CollisionSet1{});
    syss.add_comp(e, comp.Target{.team = .enemey});
    syss.add_comp(e, comp.GemDropper {.value = 50});
    return e;
}
pub fn spawn_crasher(pos: comp.Pos) Entity {
    const e: Entity = syss.new_entity();
    const size = m.measure_tex(Assets.Texs.crasher);
    syss.add_comp(e, pos);
    syss.add_comp(e, comp.Vel {
        .drag = 2,
        .rot_drag = 5,
    });
    syss.add_comp(e, comp.View { 
        .tex = &Assets.Texs.crasher, 
        .size = size,
    });
    syss.add_comp(e, comp.ShipControl {
        .thurst = 2,
        .turn_thurst = 20,
        .state = .{.dash_cd = 5},
    });
    syss.add_comp(e, comp.Size.simple(size[0]));
    syss.add_comp(e, comp.Mass {.mass = size[0] * size[1]});
    syss.add_comp(e, comp.Health {.hp = 75, .max = 75, });
    syss.add_comp(e, comp.DeadAnimation { .dead = &Assets.Anims.explode_blue});
    // syss.add_comp(e, comp.Weapon {
    //     .fire_rate = 0.5, 
    //     .bullet_spd = 2,
    //     .sound = &Assets.Sounds.shoot, 
    //     .bullet = .{.dmg = 35, .sound = &Assets.Sounds.bullet_hit, .size = 0.1, .tex = &Assets.Texs.bullet_fire}
    // });
    syss.add_comp(e, comp.Ai {.state = .{ .crasher = .{}}});
    syss.add_comp(e, comp.CollisionSet1{});
    syss.add_comp(e, comp.Target {.team = .enemey});
    syss.add_comp(e, comp.GemDropper {.value = 40});
    return e;
}


pub fn spawn_carrier(pos: comp.Pos) Entity {
    const e: Entity = syss.new_entity();
    const size = m.measure_tex(Assets.Texs.carrier);
    var new_pos = pos;
    new_pos.roundabout = true;
    syss.add_comp(e, new_pos);
    syss.add_comp(e, comp.Vel {
        .drag = 50,
        .rot_drag = 8,
    });
    syss.add_comp(e, comp.View { 
        .tex = &Assets.Texs.carrier, 
        .size = size
    });
    syss.add_comp(e, comp.ShipControl {
        .thurst = 5,
        .turn_thurst = 4,
    });
    var coll_size = comp.Size {};
    coll_size.cs[0] = .{.size = size[0], .pos = .{0, size[1]*0.15}};
    coll_size.cs[1] = .{.size = size[0]/2, .pos = .{0, size[1]*-0.25}};
    syss.add_comp(e, coll_size);
    syss.add_comp(e, comp.Mass {.mass = size[0] * size[1]});
    syss.add_comp(e, comp.Health {.hp = 500, .max = 250, .regen = 5});
    syss.add_comp(e, comp.DeadAnimation { .dead = &Assets.Anims.explode_blue});
    var weapon_comp = weapon.machine_gun();
    
    weapon_comp.append_effect(0, shoot_effect.turret());
    syss.add_comp(e, weapon_comp);

    syss.add_comp(e, comp.Ai {.state = .{ .hunter = .{}}});
    syss.add_comp(e, comp.CollisionSet1{});
    syss.add_comp(e, comp.Target {.team = .enemey});
    syss.add_comp(e, comp.GemDropper {.value = 100});
    return e;
}
