const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const m = @import("math.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const esc = @import("esc_engine.zig");

pub const Pos = struct {
    pos: m.Vec2 = .{0, 0},
    rot: f32 = 0,
    roundabout: bool = false,
};
pub const Vel = struct {
    vel: m.Vec2 = .{0, 0},
    rot: f32 = 0,
    drag: f32 = 0,
    rot_drag: f32 = 0,
};
pub const View = *rl.Texture2D;
pub const Input = struct {
    forward: c_int = rl.KEY_W,
    backward: c_int = rl.KEY_S,
    left: c_int = rl.KEY_A,
    right: c_int = rl.KEY_D,

    shoot: c_int = rl.KEY_SPACE,
};
pub const ShipControl = struct {
    thurst: f32 = 1,
    turn_thurst: f32 = 1,
    brake_rate: f32 = 1,
    state: State = .{},
    const State = struct {
        forward: bool = false,
        brake: bool = false,
        turn: enum {
            static,
            clock,
            counter,
        } = .static,

    };
    pub fn reset_state(self: *ShipControl) void {
        self.state = .{};
    }
};

pub const comp_types = [_]type{Pos, Vel, View, ShipControl, Input};
pub const Manager = esc.ComponentManager(&comp_types);


// The System interface. Impl of System should return this struct
// var ps = PhysicSystem {};
// var vs = ViewSystem {};
// var cs = ControlSystem {};
// var syss: SystemManager = undefined;
// 
// const W = 800;
// const H = 600;
// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
//     defer _ = gpa.deinit();
//     const a = gpa.allocator();
//     syss = SystemManager.init(a);
//     defer syss.deinit();
//     syss.register(cs.system(a));
//     syss.register(ps.system(a));
//     syss.register(vs.system(a));
// 
//     const e1: Entity = syss.new_entity();
//     syss.add_comp(e1, PosComp {
//         .pos = .{.x=W/2, .y=H/2},
//         .rot = 0,
//     });
//     syss.add_comp(e1, VelComp {
//         .vel = .{.x=0, .y=0},
//         .drag = 0.1,
//     });
//     syss.add_comp(e1, ViewComp {.radius = 10});
//     syss.add_comp(e1, ControlComp{});
//     // const dt: f32 = 1 / 60;
//     // syss.update(dt);
// 
//     rl.InitWindow(W, H, "zig-ecs");
//     rl.SetTargetFPS(60);
//     while (!rl.WindowShouldClose()) {
//         const dt = rl.GetFrameTime();
//         rl.BeginDrawing();
//         rl.ClearBackground(rl.RED);
//         syss.update(dt);
//         rl.EndDrawing();
//     }
// 
// }

