const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const Assets = @import("assets.zig");
const m = @import("math.zig");
const conf = @import("config.zig");
const utils = @import("utils.zig");
const AnimationPlayer = Assets.AnimationPlayer;
const Animation = Assets.Animation;
const Vec2 = m.Vec2;
const Vec2i = m.Vec2i;





var annoucement: [:0]const u8 = "";
var annouce_t: f32 = 0;
fn Annouce(s: [:0]const u8, duration: f32) void {
    annoucement = s;
    annouce_t = duration;
}

fn randf(min: f32, max: f32) f32 {
    const range = max - min;
    return randGen.random().float(f32) * range + min;
}
fn randSign() f32 {
    return if (randGen.random().float(f32) > 0.5) 1 else -1;
}

var randGen: std.Random.Xoshiro256 = undefined;
var a: std.mem.Allocator = undefined;
pub var dt: f32 = 0;
var et: f64 = 0;

// var item_water = Item{ .tex = &Assets.Texs.weapon_1 };

const esc = @import("esc_engine.zig");
const system = @import("system.zig");
const comp = @import("componet.zig");
const Entity = esc.Entity;
const syss = &system.syss;
fn spawn_player() Entity {
    const e: Entity = syss.new_entity();
    const size = 0.08;
    syss.add_comp(e, comp.Pos {});
    syss.add_comp(e, comp.Vel {
        .drag = 2,
        .rot_drag = 10,
    });
    syss.add_comp(e, comp.View { 
        .tex = &Assets.Texs.fighter, 
        .size = m.splat(size*2)
    });
    syss.add_comp(e, comp.ShipControl {
        .thurst = 3.5,
        .turn_thurst = 0.3,
    });
    syss.add_comp(e, comp.Input {});
    syss.add_comp(e, comp.Size {.size = size * 2});
    syss.add_comp(e, comp.Mass {.mass = size * size});
    syss.add_comp(e, comp.Health {.hp = 100, .max = 100});

    return e;
}
pub fn spawn_asteriod() Entity {
    const e: Entity = syss.new_entity();
    const target = Vec2{ randf(-0.75, 0.75), randf(-0.75, 0.75) };
    const pos = Vec2 { randSign() * randf(1.1, 1.5), randSign() * randf(1.1, 1.5) };
    const size = randf(0.02, 0.15);
    syss.add_comp(e, comp.Pos {
        .pos = pos,
        .rot = 0,
    });
    syss.add_comp(e, comp.Vel {
        .vel = m.v2n(target - pos) * m.splat(randf(0.05, 0.3)),
        .rot = randf(-0.005, 0.005),
        .drag = 0.01,
        .rot_drag = 1,
    });
    var ap = AnimationPlayer{ .anim = &Assets.Anims.asteroid };
    syss.add_comp(e, comp.View {.tex = @constCast(ap.play(0)), .size = m.splat(size*2)});
    syss.add_comp(e, comp.Size {.size = size*2});
    syss.add_comp(e, comp.Mass {.mass = size * size * 3});
    syss.add_comp(e, comp.Health {.hp = 100, .max = 100});

    // a.mover = m;
    // a.size = splat(randf(0.25, 0.5));

    
    // a.valid = true;
    // a.dead = false;

    // a.hp = a.size[0] * a.size[0] * 200;
    // a.dead_player = ap;

    return e;

}
var player: Entity = undefined;
pub fn DrawHUD() void {
    // const healthbar_pos = Vec
    const hp_color = rl.RED;
    const hp_bg_color = rl.Color{ .r = 100, .g = 50, .b = 50, .a = 255 };
    const hp_pos = Vec2{ 0, 0.9 };
    const hp_len = 1;
    const hp_hei = 0.005;
    {
        const hp_comp = syss.comp_man.get_comp(comp.Health, player) orelse unreachable;
        const perc = (hp_comp.hp / hp_comp.max);

        // rl.DrawRectangleV(m.coordn2srl(hp_pos), m.sizen2srl(.{0.2, 0.2}), rl.RED);
        utils.DrawRectCentered(hp_pos, .{ hp_len, hp_hei }, hp_bg_color);
        utils.DrawRectCentered(hp_pos - Vec2{ hp_len * (1 - perc) / 2, 0 }, .{ hp_len * perc, hp_hei }, hp_color);
    }

    // const gem_color = rl.GREEN;
    // const gem_bg_color = rl.Color{ .r = 50, .g = 100, .b = 50, .a = 255 };
    // const gem_pos = Vec2{ 0, 0.88 };
    // const gem_len = 0.7;
    // const gem_hei = 0.002;
    // {
    //     const perc = (@as(f32, @floatFromInt(player.gems)) / @as(f32, @floatFromInt(next_lvl_gems)));
    //     utils.DrawRectCentered(gem_pos, .{ gem_len, gem_hei }, gem_bg_color);
    //     utils.DrawRectCentered(gem_pos - Vec2{ gem_len * (1 - perc) / 2, 0 }, .{ gem_len * perc, gem_hei }, gem_color);
    // }

    // const mana_color = rl.BLUE;
    // const mana_bg_color = rl.Color{ .r = 50, .g = 50, .b = 100, .a = 255 };
    // const mana_pos = Vec2{ 0, 0.86 };
    // const mana_len = 0.7;
    // const mana_hei = 0.002;
    // {
    //     const perc = player.mana / player.max_mana;
    //     DrawRectCentered(mana_pos, .{ mana_len, mana_hei }, mana_bg_color);
    //     DrawRectCentered(mana_pos - Vec2{ mana_len * (1 - perc) / 2, 0 }, .{ mana_len * perc, mana_hei }, mana_color);
    // }
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    a = gpa.allocator();

    syss.* = system.Manager.init(a);
    defer syss.deinit();

    var ps = system.Movement {};
    var vs = system.View {};
    var cs = system.ShipControl {};
    var is = system.Input {};
    var coll = system.Collision {};
    var elastic = system.Elastic {};
    
    syss.register(is.system(a));
    syss.register(cs.system(a));
    syss.register(ps.system(a));
    syss.register(vs.system(a));
    syss.register(coll.system(a));
    syss.register(elastic.system(a));
    player = spawn_player();

    
    
    
    randGen = std.Random.DefaultPrng.init(@intCast(std.time.microTimestamp()));
    rl.InitWindow(conf.screenw, conf.screenh, "Deep Space Rouge");
    rl.SetTargetFPS(144);
    rl.SetTraceLogLevel(rl.LOG_ERROR);
    defer rl.CloseWindow();

    Assets.load();
    defer Assets.unload();

    Annouce("GAME START!", 5);
    while (!rl.WindowShouldClose()) {
        var aa = std.heap.ArenaAllocator.init(a);
        defer aa.deinit();
        dt = rl.GetFrameTime();
        et = rl.GetTime();

        // std.log.debug("t: {}", .{t});
        rl.BeginDrawing();
        {
            // rl.ClearBackground(rl.RED);
            const space_tex = &Assets.Texs.space;
            rl.DrawTexturePro(space_tex.*, .{ .x = 0, .y = 0, .width = @floatFromInt(space_tex.width), .height = @floatFromInt(space_tex.height) }, .{ .x = 0, .y = 0, .width = conf.screenw, .height = conf.screenh }, .{ .x = 0, .y = 0 }, 0, .{ .r = 0x9f, .g = 0x9f, .b = 0x9f, .a = 0xff });
            if (rl.IsKeyPressed(rl.KEY_J)) {
                _ = spawn_asteriod();
            }
            syss.update(dt);
            syss.clear_events();
            DrawHUD();
            // for (syss.systems.items) |*sys| {
            //     if (sys.set.isSet(comp.Manager.type_to_bit(comp.Collision))) {
            //         sys.entities.clearRetainingCapacity();
            //     }
            // }
            // syss.comp_man.get_arr(comp.Collision).clear();
            
        }
        rl.EndDrawing();
    }
}
