const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const Assets = @import("assets.zig");
const m = @import("math.zig");
const conf = @import("config.zig");
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
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    a = gpa.allocator();

    syss.* = system.Manager.init(a);
    defer syss.deinit();

    var ps = system.Physic {};
    var vs = system.View {};
    var cs = system.ShipControl {};
    var is = system.Input {};
    
    syss.register(is.system(a));
    syss.register(cs.system(a));
    syss.register(ps.system(a));
    syss.register(vs.system(a));

    const e1: Entity = syss.new_entity();
    syss.add_comp(e1, comp.Pos {});
    syss.add_comp(e1, comp.Vel {
        .drag = 2,
        .rot_drag = 10,
    });
    syss.add_comp(e1, &Assets.Texs.fighter);
    syss.add_comp(e1, comp.ShipControl {
        .thurst = 3.5,
        .turn_thurst = 0.3,
    });
    syss.add_comp(e1, comp.Input {});

    
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
            syss.update(dt);
        }
        rl.EndDrawing();
    }
}
