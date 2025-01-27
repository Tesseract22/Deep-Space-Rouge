const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const Assets = @import("assets");
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
const enemy = @import("enemy.zig");
const particle = @import("particle.zig");
const Entity = esc.Entity;
const syss = &system.syss;

pub var a: std.mem.Allocator = undefined;
pub var arena: std.mem.Allocator = undefined;
pub var dt: f32 = 0;
var et: f64 = 0;
pub var player: Entity = undefined;

pub fn main() !void {
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    a = gpa.allocator();

    syss.* = system.Manager.init(a);
    defer syss.deinit();

    var movement = system.Movement {};
    var view = system.View {};
    var ship_control = system.ShipControl {};
    var input = system.Input {};
    var ai = system.ShipAi.init();
    defer ai.deinit();
    var collision = system.Collision(comp.CollisionSet1) {};
    var elastic = system.Elastic {};
    var health = system.Health {};
    var anim = system.Animation {};
    var weapon = system.Weapon {};
    var bullet = system.Bullet {};
    var dead = system.Dead {.player_e = &player};
    var enemy_spawn = system.EnemeySpawner.init(a);
    defer enemy_spawn.deinit();
    var dead_anim = system.DeadAnimation {};
    var gem_dropper = system.GemDropper {};
    var collect = system.Collector {};
    var buff = system.Buff {};


    syss.register(system.get(&input, a));
    syss.register(system.get(&ai, a));
    syss.register(system.get(&ship_control, a));
    syss.register(system.get(&movement, a));

    syss.register(system.get(&view, a));
    syss.register(system.get(&anim, a));

    syss.register(system.get(&buff, a));

    syss.register(system.get(&weapon, a));
    syss.register(system.get(&collision, a));
    syss.register(system.get(&collect, a));
    syss.register(system.get(&elastic, a));
    syss.register(system.get(&health, a));
    syss.register(system.get(&bullet, a));
    syss.register(system.get(&dead_anim, a));
    syss.register(system.get(&gem_dropper, a));
    syss.register(system.get(&enemy_spawn, a));
    syss.register(system.get(&dead, a));

    std.log.debug("test", .{});
    for (0..1024) |_| {
        const e = syss.new_entity();
        syss.add_comp(e, comp.Pos {});
        syss.add_comp(e, comp.Vel {});
        syss.add_comp(e, comp.View {.tex = undefined});
        syss.add_comp(e, comp.Dead {});
        syss.del_comp(e, comp.Pos);
    }
    
}
