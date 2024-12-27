const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const m = @import("math.zig");
const assets = @import("assets.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const sys = @import("system.zig");
const esc = @import("esc_engine.zig");

const syss = &sys.syss;
pub const Team = enum {
    friendly,
    enemey,
    neutral,
};
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
pub const View = struct {
    tex: *rl.Texture2D,
    size: ?m.Vec2 = null,
};
pub const Input = struct {
    mouse: bool = false,
    forward: c_int = rl.KEY_W,
    backward: c_int = rl.KEY_S,
    left: c_int = rl.KEY_A,
    right: c_int = rl.KEY_D,
    dash: c_int = rl.KEY_LEFT_SHIFT,

    shoot: c_int = rl.KEY_SPACE,
};
pub const Weapon = struct {
    cool_down: f64 = 0,

    fire_rate: f32,
    mana_cost: f32 = 0,
    bullet_spd: f32 = 5,

    sound: ?*rl.Sound = null,
    bullet: Bullet,
};
pub const Bullet = struct {
    size: f32 = 0.02,
    tex: *rl.Texture,
    dmg: f32 = 10,
    sound: ?*rl.Sound = null,
};
pub const ShipControl = struct {
    thurst: f32 = 1,
    turn_thurst: f32 = 1,
    brake_rate: f32 = 1,
    dash_thurst: f32 = 2,
    dash_cd: f32 = 5,

    state: State = .{},
    const State = struct {
        forward: bool = false,
        brake: bool = false,
        turn: enum {
            static,
            clock,
            counter,
        } = .static,
        shoot: bool = false,
        dash: bool = false,
        dash_cd: f32 = 0,
    };
    pub fn reset_state(self: *ShipControl) void {
        self.state = .{.dash_cd = self.state.dash_cd };
    }
    pub fn turn_to_pos(control: *ShipControl, my_pos: Pos, to_pos: m.Vec2) void {
        const target_dir = to_pos - my_pos.pos;
        const target_dir_angle =
            @mod(std.math.acos(m.v2dot(m.up, target_dir) / m.v2len(target_dir)) * std.math.sign(m.v2cross(m.up, target_dir)), 2 * std.math.pi);
        return control.turn_to_dir(target_dir_angle, my_pos);
    }
    pub fn turn_to_dir(control: *ShipControl, dir: f32, my_pos: Pos) void {
        // v*t + 2*a*t*t
        // std.log.debug("dir: {}", .{@as(isize, @intFromFloat(rad2deg(dir)))});

        const turn_diff = m.diffClock(my_pos.rot, dir);
        // const turn_dir = std.math.sign(turn_diff);
        // std.log.debug("turn diff: {}, limit {}", .{turn_diff, turn_limit});
        if (turn_diff < 0) {
            control.state.turn = .counter;
        } else if (turn_diff > 0){
            control.state.turn = .clock;
        }
        // m.turn_spd = m.max_turn_spd_b * m.max_turn_spd_m * turn_dir;
        // const expected = @mod(m.turn_spd * dt + m.turn, 2 * std.math.pi);
        // const expected_diff = m.diffClock(expected, dir);
        // if (expected_diff * turn_dir <= 0) {
        //     m.turn = dir;
        //     m.turn_spd = 0;
        // }
    }
};

pub const Ai = struct {
    state: union(enum) {
        hunter: HunterAi,
        crasher: CrasherAi,
    },
    pub fn ai(self: *Ai, me: esc.Entity, player: esc.Entity, control: *ShipControl) void {
        switch (self.state) {
            inline else => |*state| state.ai(me, player, control),
        }

    }
    pub const HunterAi = struct {
        pub fn ai(self: *@This(), me: esc.Entity, player: esc.Entity, control: *ShipControl) void {
            _ = self;
            const me_pos = syss.comp_man.get_comp(Pos, me) orelse return;
            const player_pos = syss.comp_man.get_comp(Pos, player) orelse return;
            control.turn_to_pos(me_pos.*, player_pos.pos);
            
            control.state.shoot = true;
            control.state.forward = true;
        }
    };
    pub const CrasherAi = struct {
        const dash_radius = 1.5;
        pub fn ai(self: *@This(), me: esc.Entity, player: esc.Entity, control: *ShipControl) void {
            _ = self;
            const me_pos = syss.comp_man.get_comp(Pos, me) orelse return;
            const player_pos = syss.comp_man.get_comp(Pos, player) orelse return;
            const dist = m.v2dist(me_pos.pos, player_pos.pos);
            if (dist < dash_radius) {
                control.state.dash = true;
            }
            control.turn_to_pos(me_pos.*, player_pos.pos);
            control.state.forward = true;
        }
    };
};

pub const Size = struct {
    size: f32,
};
pub const Mass = struct {
    mass: f32,
};
pub const Health = struct {
    hp: f32,
    max: f32,
    regen: f32 = 0,
};
pub const DeadAnimation = struct {
    dead: *assets.Animation,
    dead_size: ?m.Vec2 = null,
};
pub const Dead = struct {

};
pub const Collision = struct {
    other: esc.Entity,
};
pub const CollisionSet1 = struct {};
pub const CollisionSet2 = struct {};

pub const GemDropper = struct {
    pub const Gem = struct {
        pub const MAX_LEVEL = 3;
        pub const Texs = [MAX_LEVEL]*rl.Texture {&assets.Texs.gem_1, &assets.Texs.gem_2, &assets.Texs.gem_3};
        pub const Sounds = [MAX_LEVEL]*rl.Sound {&assets.Sounds.gem_pickup_1, &assets.Sounds.gem_pickup_2, &assets.Sounds.gem_pickup_3};
        pub const Worths = [MAX_LEVEL]usize {1, 5, 35};

        level: u8,
    };
    value: usize,

};

pub const Collector = struct {
    collect_radius: f32,
    attract_radius: f32,
};
pub const Collectible = struct {
    sound: *rl.Sound,
    collect_radius: f32,
    attract_radius: f32,
    attract_pull: f32 = 1,
    data: union(enum) {
        gem: Gem,
    },
    pub fn effect(collectible: *Collectible, me: esc.Entity, other: esc.Entity) void {
        switch (collectible.data) {
            inline else => |*data| data.effect(collectible, me, other),
        }
    }
    pub const Gem = struct {
        level: u8,
        pub fn effect(data: *Gem, collectible: *Collectible, me: esc.Entity, other: esc.Entity) void {
            const exp = syss.comp_man.get_comp(Exp, other) orelse return;
            exp.curr_exp += GemDropper.Gem.Worths[data.level];
            _ = collectible;
            _ = me;
        }
    };
};
pub const Exp = struct {
    curr_exp: usize = 0,
    next_lvl: usize,
};

pub const comp_types = [_]type{Pos, Vel, View, ShipControl, Input, Size, Mass, Health, Dead, DeadAnimation, Exp, Collision, assets.AnimationPlayer, Weapon, Bullet, 
    CollisionSet1, CollisionSet2, Team, Ai, GemDropper, Collectible, Collector};
pub const event_types = [_]type{Collision};
pub const Manager = esc.ComponentManager(&comp_types);



