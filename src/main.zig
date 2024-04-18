const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const Assets = @import("assets.zig");
const AnimationPlayer = Assets.AnimationPlayer;
const Animation = Assets.Animation;
const Vec2 = @Vector(2, f32);
const Vec2i = @Vector(2, c_int);

const screenh = 1080;
// const screenRatio = 16.0/9.0;
const screenw = screenh * 16 / 9;

const screenhf: f32 = @floatFromInt(screenh);
const screenwf: f32 = @floatFromInt(screenw);
const screenSizef = Vec2{ screenhf, screenhf };

const aniSpeed: f32 = 4;

var cameraPos = Vec2{ 0, 0 };
var cameraPrevPos = Vec2{ 0, 0 };
var cameraAni: ?f32 = null;

const Player = struct {
    mover: Mover = .{ .spd_decay_b = 1.5, .turn_spd_decay_b = 12.5, .acc_rate_b = 3.5, .max_turn_spd_b = 400 },
    weapons: Weapons = undefined,
    mass: f32 = 1,
    size: Vec2 = .{ 0.2, 0.2 },

    dead: bool = false,
    valid: bool = true,

    hp: f32 = 50,
    max_hp: f32 = 50,
    hp_gen: f32 = 1,

    mana: f32 = 50,
    max_mana: f32 = 50,
    mana_gen: f32 = 7.5,

    gems: usize = 0,

    const Weapons = std.ArrayList(Weapon);
};

var next_lvl_gems: usize = 100;
var total_gems: usize = 0;

var player: Player = .{};
var paused: bool = false;

const objectPos = Vec2{ -0.4, 0.4 };

fn roundAbout(pos: Vec2) Vec2 {
    const screen_rang = Vec2{ 2 * screenwf / screenhf, 2 };
    const half = screen_rang / splat(2);
    return @mod(pos + half, screen_rang) - half;
}

// const DefaultBullet = struct {

// };
fn splat(i: f32) Vec2 {
    return @splat(i);
}
fn coordn2srl(v: Vec2) rl.Vector2 {
    return v2rl((v + splat(1.0)) * splat(0.5) * screenSizef + Vec2{ (screenwf - screenhf) / 2, 0.0 });
}
fn srl2sizen(v: rl.Vector2) Vec2 {
    return rl2v2(v) / screenSizef * splat(2);
}
fn srl2coord(v: rl.Vector2) Vec2 {
    return (rl2v2(v) - Vec2{ (screenwf - screenhf) / 2, 0.0 }) * splat(2) / screenSizef - splat(1.0);
}
fn sizen2srl(v: Vec2) rl.Vector2 {
    return v2rl(v * screenSizef * splat(0.5));
}
inline fn v2rl(v: Vec2) rl.Vector2 {
    return .{ .x = v[0], .y = v[1] };
}
inline fn rl2v2(rlv: rl.Vector2) Vec2 {
    return .{ rlv.x, rlv.y };
}
inline fn v2eq0(v: Vec2) bool {
    return v[0] == 0 and v[1] == 0;
}
inline fn v2lerp(from: Vec2, to: Vec2, t: f32) Vec2 {
    return (to - from) * splat(t) + from;
}
fn v2rot(v: Vec2, rot: f32) Vec2 {
    return Vec2{ @cos(rot), @sin(rot) } * splat(v[0]) + Vec2{ -@sin(rot), @cos(rot) } * splat(v[1]);
}
inline fn v2len(v: Vec2) f32 {
    return @sqrt(@reduce(.Add, v * v));
}

inline fn v2n(v: Vec2) Vec2 {
    return v / splat(v2len(v));
}
inline fn v2dist(a: Vec2, b: Vec2) f32 {
    return v2len(a - b);
}
inline fn v2dot(a: Vec2, b: Vec2) f32 {
    return @reduce(.Add, a * b);
}
inline fn v2cross(a: Vec2, b: Vec2) f32 {
    return a[0] * b[1] - b[0] * a[1];
}
inline fn rad2deg(r: f32) f32 {
    return r * 180.0 / rl.PI;
}
inline fn deg2rad(d: f32) f32 {
    return d / 180 * rl.PI;
}

inline fn DrawRectCentered(pos: Vec2, size: Vec2, c: rl.Color) void {
    rl.DrawRectangleV(coordn2srl(pos - size / splat(2.0)), sizen2srl(size), c);
}
fn DirFromKey() Vec2 {
    return
    // 		if (rl.IsKeyDown(rl.KEY_LEFT)) 	 .{-1, 0}
    // else 	if (rl.IsKeyDown(rl.KEY_RIGHT))  .{1, 0}
    // else
    if (rl.IsKeyDown(rl.KEY_UP)) .{ 0, -1 } else if (rl.IsKeyDown(rl.KEY_DOWN)) .{ 0, 1 } else .{ 0, 0 };
}
fn TurnFromKey() f32 {
    return
    // 		if (rl.IsKeyDown(rl.KEY_LEFT)) 	 .{-1, 0}
    // else 	if (rl.IsKeyDown(rl.KEY_RIGHT))  .{1, 0}
    // else
    if (rl.IsKeyDown(rl.KEY_RIGHT)) 1 else if (rl.IsKeyDown(rl.KEY_LEFT)) -1 else 0;
}

var randGen: std.Random.Xoshiro256 = undefined;
const up = Vec2{ 0, -1 };

const pixelMul: f32 = 2.5;
var debug: bool = false;
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
fn spawnAsteriod() void {
    defer asteriod_ct = (asteriod_ct + 1) % asteriods.len;
    const a = &asteriods[asteriod_ct];

    var m = Mover{};
    m.pos = .{ randSign() * randf(1.1, 1.5), randSign() * randf(1.1, 1.5) };
    m.turn = randGen.random().float(f32);
    const target = Vec2{ randf(-0.75, 0.75), randf(-0.75, 0.75) };
    m.spd = v2n(target - m.pos) * splat(randf(0.1, 0.5));
    m.turn_spd = randf(-0.75, 0.75);
    m.spd_decay_b = 0;
    a.mover = m;
    a.size = splat(randf(0.25, 0.5));

    var ap = AnimationPlayer{ .anim = &Assets.Anims.asteroid, .size = a.size };
    a.tex = @constCast(ap.play(0));

    a.valid = true;
    a.dead = false;

    a.hp = a.size[0] * a.size[0] * 200;
    a.dead_player = ap;
}

fn diffClock(from: f32, to: f32) f32 {
    const p = 2 * rl.PI; // period
    var clock: f32 = undefined;
    var counter: f32 = undefined;
    if (to > from) {
        clock = to - from;
        counter = from - to + p;
    } else {
        clock = to - from + p;
        counter = from - to;
    }
    return if (clock < counter) clock else -counter;
}
const ObjectT = enum {
    Bullet,
    Asteriod,
    Player,
    Enemy,
};
const Object = union(ObjectT) {
    Bullet: *Bullet,
    Asteriod: *Asteriod,
    Player: *Player,
    Enemy: *Enemy,

    // pub fn init(a: anytype, comptime t: ObjectT) Object {
    // 	return switch (t) {
    // 		.Bullet => .{.Bullet = a },
    // 		.Asteriod => .{.Asteriod = a},
    // 		.Enemy => .{.Enemy = a},
    // 		.Player => unreachable
    // 	};
    // }
};
pub const Gem = struct {
    lvl: u8 = 0,
    mover: Mover = .{},
    valid: bool = false,
    pub const Texs: [3]*rl.Texture = .{ &Assets.Texs.gem_1, &Assets.Texs.gem_2, &Assets.Texs.gem_3 };
    pub const Values: [3]usize = .{ 1, 5, 35 };
    pub fn spawnGem(value: usize, pos: Vec2) void {
        var left = value;
        var cts = [_]usize{0} ** 3;
        for (0..3) |i| {
            const ri = 3 - i - 1;
            cts[ri] = left / Values[ri];
            left -= cts[ri] * Values[ri];
        }
        for (cts, 0..) |ct, lvl| {
            for (0..ct) |_| {
                defer gem_ct = (gem_ct + 1) % gems.len;
                const g = &gems[gem_ct];
                g.lvl = @intCast(lvl);
                g.valid = true;
                g.mover.pos = pos;
                g.mover.spd = .{ randf(-0.2, 0.2), randf(-0.2, 0.2) };
                g.mover.turn = randf(0, 360);
                g.mover.turn_spd = randf(-1, 1);
                g.mover.spd_decay_b = 1;
            }
        }
    }
};
const Bullet = struct {
    mover: Mover = .{},
    by: ?*Weapon = null,
    size: Vec2 = .{ 0.05, 0.05 },
    dmg: f32 = 0,

    tex: ?*rl.Texture2D = null,
    dead_player: AnimationPlayer = undefined,

    valid: bool = false,
    dead: bool = false,
    pub fn onhit(b: *Bullet, other: Object, ai: bool) void {
        if (b.by) |w| {
            if (ai) w.ai_onhit(w, b, other, 0) else w.onhits.getLast()(w, b, other, w.onhits.items.len - 1);
        }
    }

    // size: Vec2,
};

const Asteriod = struct {
    mover: Mover = .{},

    size: Vec2 = .{ 0.1, 0.1 },
    hp: f32 = 50,
    mass: f32 = 10,

    tex: ?*rl.Texture2D = null,
    dead_player: AnimationPlayer = undefined,
    dead: bool = true,
    valid: bool = false,
};

const Mover = struct {
    // state that should no be directly modified
    spd: Vec2 = .{ 0, 0 },
    pos: Vec2 = .{ 0, 0 },
    turn: f32 = 0,
    turn_spd: f32 = 0, // turnning does not have acceleration (or infinite acceleration)

    acc_rate_b: f32 = 0.8,
    spd_decay_b: f32 = 1, // no decay by default

    turn_spd_decay_b: f32 = 1,
    max_turn_spd_b: f32 = 5,

    acc_rate_m: f32 = 1,
    spd_decay_m: f32 = 1, // no decay by default
    max_spd_m: f32 = 1,

    turn_spd_decay_m: f32 = 1,
    max_turn_spd_m: f32 = 1,

    pub fn turnToPos(m: *Mover, pos: Vec2) void {
        const target_dir = pos - m.pos;
        const target_dir_angle =
            @mod(std.math.acos(v2dot(up, target_dir) / v2len(target_dir)) * std.math.sign(v2cross(up, target_dir)), 2 * rl.PI);
        return m.turnToDir(target_dir_angle);
    }
    pub fn turnToDir(m: *Mover, dir: f32) void {
        // v*t + 2*a*t*t
        // std.log.debug("dir: {}", .{@as(isize, @intFromFloat(rad2deg(dir)))});

        const turn_diff = diffClock(m.turn, dir);
        const turn_dir = std.math.sign(turn_diff);
        // std.log.debug("turn diff: {}, limit {}", .{turn_diff, turn_limit});

        m.turn_spd = m.max_turn_spd_b * m.max_turn_spd_m * turn_dir;
        const expected = @mod(m.turn_spd * dt + m.turn, 2 * rl.PI);
        const expected_diff = diffClock(expected, dir);
        if (expected_diff * turn_dir <= 0) {
            m.turn = dir;
            m.turn_spd = 0;
        }
    }
    pub fn foward(m: *Mover) void {
        m.spd += v2rot(up, m.turn) * splat(dt * m.acc_rate_b * m.acc_rate_m);
    }
    pub fn move(m: *Mover) void {
        m.turn += m.turn_spd * dt;
        m.turn = @mod(m.turn, 2 * rl.PI);
        m.pos += m.spd * splat(dt);
        m.spd = m.spd * splat(1 - (m.spd_decay_b * m.spd_decay_m) * dt);
    }
    // pub fn turn(self: *Move)

};
const Weapon = struct {
    prev_fire: f64 = 0,

    fire_rate_b: f32,
    fire_rate_m: f32 = 1,
    mana_cost_b: f32 = 0,
    mana_cost_m: f32 = 1,
    dmg_b: f32 = 5,
    dmg_m: f32 = 1,
    bullet_spd_b: f32 = 5,
    bullet_spd_m: f32 = 1,

    shoots: Shoots,
    ai_shoot: *const ShootFn = undefined,
    onhits: Onhits,
    ai_onhit: *const OnhitFn = undefined,

    buff_ct: usize = 0,

    pub const ShootFn = fn (*Weapon, dir: f32, init_spd: Vec2, pos: Vec2, idx: usize) void;
    pub const Shoots = std.ArrayList(*const ShootFn);
    pub const OnhitFn = fn (*Weapon, *Bullet, Object, usize) void;
    pub const Onhits = std.ArrayList(*const OnhitFn);
    pub fn ShootFoward(w: *Weapon, m: *Mover) void {
        w.shoots.getLast()(w, m.turn, m.spd + v2rot(up, m.turn) * splat(w.bullet_spd_b * w.bullet_spd_m), m.pos, w.shoots.items.len - 1);
    }
    pub fn ShootFowardAI(w: *Weapon, m: *Mover) void {
        w.ai_shoot(w, m.turn, m.spd + v2rot(up, m.turn) * splat(w.bullet_spd_b * w.bullet_spd_m), m.pos, 0);
    }
    pub fn defaultHit(_: *Weapon, b: *Bullet, other: Object, _: usize) void {
        b.dead = true;
        switch (other) {
            inline .Asteriod, .Enemy, .Player => |o| {
                o.hp -= b.dmg;
            },
            else => {},
        }
    }
};
const ChargeState = union(enum) {
    Finding,
    Charging: f32,
    Attacking: f32,
    Cooling: f32,

    pub var charge_t: f32 = 3;
    pub var attack_t: f32 = 0.75;
    pub var cool_t: f32 = 5;
};
const EnemyExtra = union(enum) {
    None,
    Charge: ChargeState,
};

const Enemy = struct {
    mover: Mover = .{},
    valid: bool = false,
    dead: bool = false,
    size: Vec2 = .{ 0.15, 0.15 },
    // weapon: Weapon = .{},

    hp: f32 = 0,
    mass: f32 = 1,

    tex: ?*rl.Texture2D = null,
    warmhole_player: AnimationPlayer = undefined,
    explode_player: AnimationPlayer = undefined,

    weapon: Weapon = .{
        .fire_rate_b = 0.2,
        .shoots = undefined,
        .onhits = undefined,
    },

    extra: EnemyExtra = .None,
    ai: ?*const AiFn = null,

    worth: usize = 0,
    pub const AiFn = fn (*Enemy) void;

    fn spawnHunter() void {
        defer enemy_ct = (enemy_ct + 1) % enemies.len;
        const ap = AnimationPlayer{ .anim = &Assets.Anims.wormhole, .spd = 10 };
        const e = &enemies[enemy_ct];
        e.valid = true;
        e.dead = false;
        e.tex = @constCast(&Assets.Texs.hunter);
        e.warmhole_player = ap;

        e.hp = 100;

        e.mover.pos = .{ randf(-0.8, 0.8), randf(-0.8, 0.8) };
        e.mover.max_turn_spd_b = 1;
        e.mover.acc_rate_b = 1;
        e.mover.spd_decay_b = 2;
        e.mover.turn = randf(0, 360);
        e.explode_player = AnimationPlayer{ .anim = &Assets.Anims.explode_blue };

        e.worth = 55;

        e.weapon.fire_rate_b = 0.2;
        e.weapon.bullet_spd_b = 0.5;
        e.weapon.ai_shoot = struct {
            pub fn impl(w: *Weapon, dir: f32, spd: Vec2, pos: Vec2, _: usize) void {
                if (et - w.prev_fire >= 1 / w.fire_rate_b) {
                    w.prev_fire = et;
                    defer ebullet_ct = (ebullet_ct + 1) % ebullets.len;
                    const b = &ebullets[ebullet_ct];
                    b.tex = &Assets.Texs.bullet_fire;

                    var m = Mover{};
                    m.pos = pos;
                    m.spd = spd;
                    m.spd_decay_b = 0;
                    m.turn = dir;

                    b.by = w;
                    b.mover = m;
                    b.dmg = 5;
                    b.dead_player = AnimationPlayer{ .anim = &Assets.Anims.explode_blue, .spd = 15, .size = b.size };
                    b.valid = true;
                    b.dead = false;
                }
            }
        }.impl;
        e.weapon.ai_onhit = Weapon.defaultHit;
        e.ai = struct {
            pub fn impl(enemy: *Enemy) void {
                const m = &enemy.mover;
                m.turnToPos(player.mover.pos);
                if (v2dist(player.mover.pos, m.pos) > 0.75)
                    m.foward();
                m.move();
                enemy.weapon.ShootFowardAI(m);
            }
        }.impl;
        e.extra = .None;
    }
    fn spawnCrasher() void {
        defer enemy_ct = (enemy_ct + 1) % enemies.len;
        const ap = AnimationPlayer{ .anim = &Assets.Anims.wormhole, .spd = 10 };
        const e = &enemies[enemy_ct];
        e.tex = @constCast(&Assets.Texs.crasher);
        e.warmhole_player = ap;
        e.hp = 20;
        e.mover.pos = .{ randf(-0.8, 0.8), randf(-0.8, 0.8) };
        e.mover.max_turn_spd_b = 3;
        e.mover.acc_rate_b = 10;
        e.mover.spd_decay_b = 15;
        e.mover.turn = randf(0, 360);
        e.explode_player = AnimationPlayer{ .anim = &Assets.Anims.explode_blue };
        e.valid = true;
        e.dead = false;
        e.weapon.fire_rate_b = 1;
        // e.weapon.shoot = struct {
        // 	pub fn impl(_: *Weapon, _: f32, _: Vec2, _: Vec2) void {
        // 	}
        // }.impl;
        e.extra = .{ .Charge = .Finding };
        e.worth = 37;
        e.ai = struct {
            pub fn impl(enemy: *Enemy) void {
                _ = et; // autofix
                const charge_state = &enemy.extra.Charge;
                const m = &enemy.mover;
                const pm = &player.mover;

                switch (charge_state.*) {
                    .Finding => {
                        m.acc_rate_m = 1;
                        if (v2dist(m.pos, pm.pos) < 0.5) {
                            charge_state.* = .{ .Charging = 0 };
                        }
                    },
                    .Charging => |*ct| {
                        ct.* += dt;
                        m.acc_rate_m = 0.15;
                        if (ct.* > ChargeState.charge_t) {
                            charge_state.* = .{ .Attacking = 0 };
                        }
                        // m.spd = 1.5;
                        // m.move(dt);
                    },
                    .Attacking => |*at| {
                        at.* += dt;
                        m.acc_rate_m = 2.75;
                        m.max_turn_spd_m = 0.1;
                        if (at.* > 1) {
                            charge_state.* = .{ .Cooling = 0 };
                        }
                    },
                    .Cooling => |*ct| {
                        m.acc_rate_m = 0.25;
                        m.max_turn_spd_m = 1;
                        m.turnToPos(pm.pos);
                        m.move();
                        ct.* += dt;
                        if (ct.* > ChargeState.cool_t) {
                            charge_state.* = .Finding;
                            m.max_spd_m = 1;
                        }
                    },
                }
                m.turnToPos(pm.pos);
                m.foward();
                m.move();
            }
        }.impl;
    }
};

fn testHit(x: *Bullet, y: anytype, comptime t: ObjectT, ai: bool) void {
    if (y.dead or !y.valid) return;
    const dist = v2dist(x.mover.pos, y.mover.pos);
    if (dist < (x.size[0] + y.size[0]) / 2) {
        x.onhit(@unionInit(Object, @tagName(t), y), ai);
        rl.PlaySound(Assets.Sounds.bullet_hit);
    }
}

fn testHits(xs: []Bullet, ys: anytype, comptime t: ObjectT, ai: bool) void {
    for (xs) |*x| {
        if (x.dead or !x.valid) continue;
        for (ys) |*y| {
            testHit(x, y, t, ai);
        }
    }
}
fn testCollide(x: anytype, y: anytype, dmg: bool) void {
    const dist = v2dist(x.mover.pos, y.mover.pos);
    if (dist < (x.size[0] + y.size[0]) / 2) {
        const m = x.mass + y.mass;
        const wx = y.mass / m;
        const wy = x.mass / m;
        const d = v2n(x.mover.pos - y.mover.pos);
        const xs = v2dot(x.mover.spd, d);
        const ys = v2dot(y.mover.spd, d);
        const s = xs - ys;
        if (s >= 0) return;
        // rl.PlaySound(Assets.Sounds.collide);
        if (dmg) {
            y.hp -= wy * (-s) * 10;
            x.hp -= wx * (-s) * 10;
        }

        x.mover.spd -= splat(wx * (1 + elastic) * s) * d;
        y.mover.spd += splat(wy * (1 + elastic) * s) * d;

        const diff = (x.size[0] + y.size[0]) / 2 - dist;
        x.mover.pos += splat(0.5 * diff) * d;
        y.mover.pos -= splat(0.5 * diff) * d;
    }
}
// fn collideDamage(x: anytype, y: anytype) void {

// }
fn testCollides(xs: anytype, ys: anytype, dmg: bool) void {
    for (xs) |*x| {
        if (!x.valid or x.dead) continue;
        for (ys) |*y| {
            if (!y.valid or y.dead) continue;
            testCollide(x, y, dmg);
        }
    }
}
fn testCollideSelf(xs: anytype) void {
    for (xs[0 .. xs.len - 1], 0..) |*x1, i| {
        if (x1.dead or !x1.valid) continue;
        for (xs[i + 1 ..]) |*x2| {
            if (x2.dead or !x2.valid) continue;
            testCollide(x1, x2, false);
        }
    }
}
fn playAnim(anim: *Animation) void {
    defer anim_ct = (anim_ct + 1) % anims.len;
    const a: AnimationPlayer = &anim[anim_ct];
    a.anim = anim;
    a.curr_frame = 0;
    a.valid = true;
}
const bw = 5;
const bh = 5;
const blk_size = srl2sizen(.{ .x = 32 * pixelMul, .y = 32 * pixelMul });
var inventory = [_][bw]?usize{[_]?usize{null} ** bw} ** bh;
const Items = std.AutoArrayHashMap(usize, Item);
var items: Items = undefined;
var item_id: usize = 0;
var selected_item: ?usize = null;
fn DrawText(v: Vec2, text: [:0]const u8, font_size: u8, color: rl.Color) void {
    const pos = coordn2srl(v);
    rl.DrawText(text, @intFromFloat(pos.x), @intFromFloat(pos.y), font_size, color);
}
fn DrawItem(item: Item, pos: Vec2) void {
    //  q
    const spos = coordn2srl(pos - blk_size / splat(2));
    rl.DrawTextureEx(item.tex.*, spos, 0, pixelMul, rl.WHITE);
}
fn checkItemBound(bc: @Vector(2, i32)) bool {
    return bc[0] >= 0 and bc[1] >= 0 and bc[0] < bw and bc[1] < bh;
}
fn checkItemOccupied(bc: @Vector(2, u8)) bool {
    return inventory[bc[0]][bc[1]] == null;
}
fn tryPlaceItem(bc: @Vector(2, i32), si: *Item) bool {
    for (si.shape) |shape_coord| {
        const c = bc + (shape_coord orelse @Vector(2, u8){ 0, 0 });
        if (!checkItemBound(c) or !checkItemOccupied(@intCast(c))) {
            return false;
        }
    } else {
        dropItem(si);
        si.pos = .{ @intCast(bc[0]), @intCast(bc[1]) };
        for (si.shape) |shape_coord| {
            const c = bc + (shape_coord orelse break);
            inventory[@intCast(c[0])][@intCast(c[1])] = si.id;
        }
        selected_item = null;
        return true;
    }
}
fn dropItem(si: *Item) void {
    if (si.pos) |old_pos| {
        for (si.shape) |shape_coord| {
            const c = old_pos + (shape_coord orelse @Vector(2, u8){ 0, 0 });
            inventory[@intCast(c[0])][@intCast(c[1])] = null;
        }
        si.pos = null;
    }
}
fn DrawItemMenu() void {
    const blk_tex = &Assets.Texs.block;
    // darken the background
    rl.DrawRectangle(9, 9, screenw, screenh, rl.Color{ .r = 0, .b = 0, .g = 0, .a = 0x7f });
    // draw the grid

    for (0..bw) |x| {
        const xf: f32 = @floatFromInt(x);
        for (0..bh) |y| {
            const yf: f32 = @floatFromInt(y);
            const origin = blk_size * Vec2{ xf - (@as(f32, @floatFromInt(bw)) - 1) / 2, yf - (@as(f32, @floatFromInt(bh)) - 1) / 2 };
            DrawTexture(blk_tex.*, origin, null, 0);
        }
    }
    // items come on top of grid
    for (0..bw) |x| {
        const xf: f32 = @floatFromInt(x);
        for (0..bh) |y| {
            const yf: f32 = @floatFromInt(y);
            const origin = Vec2{ blk_size[0], blk_size[1] } * Vec2{ xf - (@as(f32, @floatFromInt(bw)) - 1) / 2, yf - (@as(f32, @floatFromInt(bh)) - 1) / 2 };
            if (inventory[x][y]) |id| {
                const item = items.get(id) orelse unreachable;
                if (item.pos.?[0] == x and item.pos.?[1] == y) DrawItem(item, origin);
                // std.log.debug("draw item", .{})

            }
        }
    }
    var it = items.iterator();
    const list_x = -1.2;
    const list_y = -0.8;
    const list_h = 0.04;
    const list_w = 0.3;
    const list_space = 0.04;
    var list_ct: usize = 0;
    while (it.next()) |entry| : (list_ct += 1) {
        const item = entry.value_ptr;
        const ct: f32 = @floatFromInt(list_ct);
        rl.DrawRectangleV(coordn2srl(.{ list_x - 0.01, list_y + ct * list_space }), sizen2srl(.{ list_w, list_h }), rl.BEIGE);
        DrawText(.{ list_x, list_y + ct * list_space }, item.name, 20, rl.WHITE);
    }

    // draw the selected item

    const mouse_sv = rl.GetMousePosition();
    const mouse_v = srl2coord(mouse_sv);
    const mouse_list = @divFloor(mouse_v[1] - list_y, list_space);
    const mouse_list_i: isize = @intFromFloat(mouse_list);
    if (mouse_v[0] >= list_x and mouse_v[0] < list_x + list_w and mouse_list_i < list_ct and mouse_list_i >= 0) {
        const pos = coordn2srl(.{ list_x - 0.01, list_y + mouse_list * list_space });
        const size = sizen2srl(.{ list_w, list_h });
        rl.DrawRectangleLinesEx(.{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y }, 1, rl.WHITE);
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            it = items.iterator();
            list_ct = 0;
            selected_item = while (it.next()) |entry| : (list_ct += 1) {
                if (list_ct == mouse_list_i) break entry.value_ptr.id;
            } else unreachable;
        }
    }
    const bc: @Vector(2, i32) = @intFromFloat(mouse_v / blk_size + splat(2.5));
    if (selected_item) |id| {
        const si = items.getPtr(id) orelse unreachable;
        DrawItem(si.*, mouse_v);
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            if (!tryPlaceItem(bc, si)) {
                dropItem(si);
            }
            CalItem();
        }
    } else {
        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT) and checkItemBound(bc)) {
            selected_item = inventory[@intCast(bc[0])][@intCast(bc[1])];
        }
    }

    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
        selected_item = null;
    }
}

var enemies: [128]Enemy = [_]Enemy{Enemy{}} ** 128;
var enemy_ct: usize = 0;

var bulletSize = Vec2{ 0.05, 0.05 };
var bullets: [1024]Bullet = [_]Bullet{Bullet{}} ** 1024;
var bullet_ct: usize = 0;

var ebullets: [1024]Bullet = [_]Bullet{Bullet{}} ** 1024;
var ebullet_ct: usize = 0;

var anims: [64]AnimationPlayer = [_]AnimationPlayer{AnimationPlayer{}} ** 64;
var anim_ct: usize = 0;

var asteriods: [10]Asteriod = [_]Asteriod{Asteriod{}} ** 10;
var asteriod_ct: usize = 0;

var gems: [64]Gem = [_]Gem{Gem{}} ** 64;
var gem_ct: usize = 0;

const Spawner = struct {
    var wave_ct: usize = 0;
    var wave_worth: f32 = 25;
    var wave_left: usize = 0;
    const enemy_weights = [_]std.meta.Tuple(&[_]type{ (*const fn () void), f32 }){ .{ Enemy.spawnCrasher, 15 }, .{ Enemy.spawnHunter, 30 } };
    fn SpawnWave() void {
        Annouce("New Wave!", 2);

        var total: f32 = 0;
        while (total < wave_worth) {
            const t = enemy_weights[randGen.next() % enemy_weights.len];
            const max_t: usize = @intFromFloat((wave_worth - total) / t[1] + 0.5);
            const n: usize = @intCast(rl.GetRandomValue(1, @intCast(max_t))); // at least 1
            for (0..n) |_| {
                t[0]();
            }
            wave_left += n;
            total += @as(f32, @floatFromInt(n)) * t[1];
            spawnAsteriod();
        }
    }
    const item_weight = [_]std.meta.Tuple(&[_]type{ (*const fn () Item), f32 }){
        .{ Item.water, 1 },
        .{ Item.weight, 1 },
        .{ Item.energy_bullet, 1 },
        .{ Item.triple_shots, 1 },
        .{ Item.basic_gun, 1 },
        .{ Item.machine_gun, 1 },
    };
    fn SpawnItem() void {
        const i = item_weight[randGen.next() % item_weight.len];
        const item = i[0]();
        // std.log.debug("spawned: {s}", .{item.name});
        items.put(item.id, item) catch unreachable;

        selected_item = item.id;
    }
};

fn playDeadAnim(o: anytype) void {
    std.debug.assert(o.valid and o.dead);
    const ap: *AnimationPlayer = &o.dead_player;
    const m: Mover = o.mover;
    const tex = ap.play(dt);
    DrawTexture(tex.*, m.pos, ap.size, m.turn);
    if (ap.isLast()) {
        o.valid = false;
    }
}

fn MeasureTex(tex: rl.Texture2D) rl.Vector2 {
    return .{ .x = @as(f32, @floatFromInt(tex.width)) * pixelMul, .y = @as(f32, @floatFromInt(tex.height)) * pixelMul };
}

pub inline fn DrawTexture(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32) void {
    DrawTextureTint(tex, origin, size, rot, rl.WHITE);
}

pub fn DrawTextureTint(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32, tint: rl.Color) void {
    const pos = coordn2srl(origin);
    const tw: f32 = @floatFromInt(tex.width);
    const th: f32 = @floatFromInt(tex.height);
    var dw: f32 = 0;
    var dh: f32 = 0;
    if (size) |s| {
        const dest = sizen2srl(s);
        dw = dest.x;
        dh = dest.y;
    } else {
        dw = tw * pixelMul;
        dh = th * pixelMul;
    }
    rl.DrawTexturePro(tex, .{ .x = 0, .y = 0, .width = tw, .height = th }, .{ .x = pos.x, .y = pos.y, .width = dw, .height = dh }, .{ .x = dw / 2, .y = dh / 2 }, rot / rl.PI * 180.0, tint);
    if (debug)
        rl.DrawCircleLinesV(pos, @max(dw, dh) / 2, rl.RED); // debug

}

const Item = struct {
    shape: [5]?@Vector(2, u8) = .{ .{ 0, 0 }, null, null, null, null },
    pos: ?@Vector(2, u8) = null,
    id: usize,
    tex: *rl.Texture2D,
    name: [:0]const u8,
    type: ItemType,

    const ItemType = union(enum) {
        Weapon: Weapon,
        WeaponBuff: (*const fn (*Weapon) void),
    };

    pub fn water() Item {
        defer item_id += 1;
        const buff = struct {
            pub fn impl(w: *Weapon) void {
                w.mana_cost_m -= 0.2;
            }
        }.impl;
        return .{ .tex = &Assets.Texs.water, .id = item_id, .name = "water", .type = .{ .WeaponBuff = buff } };
    }
    pub fn basic_gun() Item {
        defer item_id += 1;
        const shoot = struct {
            pub fn impl(w: *Weapon, dir: f32, spd: Vec2, pos: Vec2, _: usize) void {
                if (et - w.prev_fire < 1 / (w.fire_rate_b * w.fire_rate_m) or player.mana < w.mana_cost_b) return;
                w.prev_fire = et;
                player.mana -= w.mana_cost_b * w.mana_cost_m;
                defer bullet_ct = (bullet_ct + 1) % bullets.len;
                const b = &bullets[bullet_ct];

                var m = Mover{};
                m.pos = pos;
                m.spd = spd;
                m.turn = dir;
                m.spd_decay_b = 0;

                b.mover = m;
                b.by = w;
                b.dmg = w.dmg_b * w.dmg_m;
                b.dead_player = AnimationPlayer{ .anim = &Assets.Anims.explode_blue, .spd = 15, .size = b.size };
                b.valid = true;
                b.dead = false;
                b.tex = &Assets.Texs.bullet;
                rl.PlaySound(Assets.Sounds.shoot);
            }
        }.impl;
        var shoots = Weapon.Shoots.initCapacity(c_alloc, 1) catch unreachable;
        shoots.append(shoot) catch unreachable;
        var onhits = Weapon.Onhits.initCapacity(c_alloc, 1) catch unreachable;
        onhits.append(Weapon.defaultHit) catch unreachable;
        return .{ .tex = &Assets.Texs.weapon_1, .shape = .{ .{ 0, 0 }, .{ 0, 1 }, null, null, null }, .id = item_id, .name = "basic gun", .type = .{ .Weapon = .{ .fire_rate_b = 10, .shoots = shoots, .onhits = onhits, .mana_cost_b = 2, .bullet_spd_b = 2 } } };
    }
    pub fn weight() Item {
        defer item_id += 1;
        const buff = struct {
            pub fn impl(w: *Weapon) void {
                w.bullet_spd_m -= 0.3;
                w.dmg_m += 0.5;
                w.mana_cost_m += 0.1;
            }
        }.impl;
        return .{
            .tex = &Assets.Texs.weight,
            .id = item_id,
            .name = "weight",
            .type = .{ .WeaponBuff = buff },
        };
    }
    pub fn triple_shots() Item {
        defer item_id += 1;
        const buff = struct {
            pub fn impl(w: *Weapon) void {
                const new_shoot = struct {
                    pub fn impl(w2: *Weapon, dir: f32, spd: Vec2, pos: Vec2, idx: usize) void {
                        const old_shoot = w2.shoots.items[idx - 1];
                        const prev_fire = w2.prev_fire;
                        const mana_cost_m = w2.mana_cost_m;
                        w2.mana_cost_m = 0;
                        old_shoot(w2, dir, spd, pos, idx - 1);
                        w2.prev_fire = prev_fire;

                        w2.mana_cost_m = 0;
                        old_shoot(w2, dir + rl.PI / 12, v2rot(spd, rl.PI / 12), pos, idx - 1);
                        w2.prev_fire = prev_fire;

                        w2.mana_cost_m = mana_cost_m * 2;
                        old_shoot(w2, dir - rl.PI / 12, v2rot(spd, -rl.PI / 12), pos, idx - 1);
                        w2.mana_cost_m = mana_cost_m;
                    }
                }.impl;
                w.shoots.append(new_shoot) catch unreachable;
            }
        }.impl;
        return .{
            .tex = &Assets.Texs.triple_shots,
            .shape = .{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 }, null, null },
            .id = item_id,
            .name = "triple",
            .type = .{ .WeaponBuff = buff },
        };
    }
    pub fn energy_bullet() Item {
        defer item_id += 1;
        const buff = struct {
            pub fn impl(w: *Weapon) void {
                const onhit = struct {
                    pub fn impl(w2: *Weapon, b: *Bullet, o: Object, idx: usize) void {
                        player.mana = @min(player.mana + 5, player.max_mana);
                        w2.onhits.items[idx - 1](w2, b, o, idx - 1);
                    }
                }.impl;
                w.onhits.append(onhit) catch unreachable;
            }
        }.impl;
        return .{
            .tex = &Assets.Texs.energy_bullet,
            .id = item_id,
            .name = "energy bullet",
            .type = .{ .WeaponBuff = buff },
        };
    }

    pub fn machine_gun() Item {
        defer item_id += 1;
        const shoot = struct {
            pub fn impl(w: *Weapon, dir: f32, spd: Vec2, pos: Vec2, _: usize) void {
                if (et - w.prev_fire < 1 / (w.fire_rate_b * w.fire_rate_m) or player.mana < w.mana_cost_b) return;
                w.prev_fire = et;
                player.mana -= w.mana_cost_b * w.mana_cost_m;

                for (0..w.buff_ct + 1) |_| {
                    defer bullet_ct = (bullet_ct + 1) % bullets.len;
                    const b = &bullets[bullet_ct];
                    var m = Mover{};
                    m.pos = pos + Vec2{ randf(-0.02, 0.02), randf(-0.02, 0.02) };
                    const rand_turn = randf(-5, 5) / 180 * rl.PI;

                    m.spd = v2rot(spd, rand_turn);
                    m.turn = dir + rand_turn;
                    m.spd_decay_b = 0;
                    b.mover = m;
                    b.by = w;
                    b.dmg = w.dmg_b * w.dmg_m;
                    b.dead_player = AnimationPlayer{ .anim = &Assets.Anims.explode_blue, .spd = 15, .size = b.size };
                    b.valid = true;
                    b.dead = false;
                    b.tex = &Assets.Texs.bullet_2;
                }

                rl.PlaySound(Assets.Sounds.shoot);
            }
        }.impl;
        var shoots = Weapon.Shoots.initCapacity(c_alloc, 1) catch unreachable;
        shoots.append(shoot) catch unreachable;
        var onhits = Weapon.Onhits.initCapacity(c_alloc, 1) catch unreachable;
        onhits.append(Weapon.defaultHit) catch unreachable;
        return .{ .tex = &Assets.Texs.machine_gun, .shape = .{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, null, null }, .id = item_id, .name = "machine gun", .type = .{ .Weapon = .{ .fire_rate_b = 20, .dmg_b = 2, .shoots = shoots, .onhits = onhits, .mana_cost_b = 1, .bullet_spd_b = 1.5 } } };
    }
};
pub fn neighbor(item: *Item) Items {
    const V = @Vector(2, i32);
    var neighbors = Items.init(c_alloc);
    for (item.shape) |shape_coord| {
        const bc: @Vector(2, i32) = @intCast((shape_coord orelse break) + item.pos.?);
        const neigh: [4]V = .{
            bc + V{ 1, 0 },
            bc + V{ -1, 0 },
            bc + V{ 0, 1 },
            bc + V{ 0, -1 },
        };
        for (neigh) |nc| {
            if (!checkItemBound(nc)) continue;
            const n: *Item = items.getPtr(inventory[@intCast(nc[0])][@intCast(nc[1])] orelse continue) orelse unreachable;
            if (n.id == item.id) continue;
            neighbors.put(n.id, n.*) catch unreachable;
        }
    }
    return neighbors;
}
// if (Weapon.)
pub fn CalItem() void {
    var it = items.iterator();
    player.weapons.shrinkRetainingCapacity(0);
    while (it.next()) |entry| {
        const item = entry.value_ptr;
        _ = item.pos orelse continue;
        switch (item.type) {
            .Weapon => |*w| {
                w.fire_rate_m = 1;
                w.mana_cost_m = 1;
                w.dmg_m = 1;
                w.bullet_spd_m = 1;
                w.shoots.resize(1) catch unreachable;
                w.onhits.resize(1) catch unreachable;
                w.buff_ct = 0;
                var ns = neighbor(item);
                defer ns.deinit();
                var it2 = ns.iterator();
                while (it2.next()) |entry2| {
                    const n = entry2.value_ptr;
                    switch (n.type) {
                        .WeaponBuff => |buff| {
                            buff(w);
                            w.buff_ct += 1;
                        },
                        else => {},
                    }
                }
                player.weapons.append(w.*) catch unreachable;
            },
            else => {},
        }
    }
}
const elastic = 0.9;
pub fn DrawHUD() void {
    // const healthbar_pos = Vec
    const hp_color = rl.RED;
    const hp_bg_color = rl.Color{ .r = 100, .g = 50, .b = 50, .a = 255 };
    const hp_pos = Vec2{ 0, 0.9 };
    const hp_len = 0.7;
    const hp_hei = 0.002;
    {
        const perc = (player.hp / player.max_hp);
        DrawRectCentered(hp_pos, .{ hp_len, hp_hei }, hp_bg_color);
        DrawRectCentered(hp_pos - Vec2{ hp_len * (1 - perc) / 2, 0 }, .{ hp_len * perc, hp_hei }, hp_color);
    }

    const gem_color = rl.GREEN;
    const gem_bg_color = rl.Color{ .r = 50, .g = 100, .b = 50, .a = 255 };
    const gem_pos = Vec2{ 0, 0.88 };
    const gem_len = 0.7;
    const gem_hei = 0.002;
    {
        const perc = (@as(f32, @floatFromInt(player.gems)) / @as(f32, @floatFromInt(next_lvl_gems)));
        DrawRectCentered(gem_pos, .{ gem_len, gem_hei }, gem_bg_color);
        DrawRectCentered(gem_pos - Vec2{ gem_len * (1 - perc) / 2, 0 }, .{ gem_len * perc, gem_hei }, gem_color);
    }

    const mana_color = rl.BLUE;
    const mana_bg_color = rl.Color{ .r = 50, .g = 50, .b = 100, .a = 255 };
    const mana_pos = Vec2{ 0, 0.86 };
    const mana_len = 0.7;
    const mana_hei = 0.002;
    {
        const perc = player.mana / player.max_mana;
        DrawRectCentered(mana_pos, .{ mana_len, mana_hei }, mana_bg_color);
        DrawRectCentered(mana_pos - Vec2{ mana_len * (1 - perc) / 2, 0 }, .{ mana_len * perc, mana_hei }, mana_color);
    }
}
pub fn DrawRestart() void {
    DrawRectCentered(.{ 0, 0 }, .{ 0.8, 0.1 }, rl.Color{ .r = 0x7f, .g = 0x7f, .b = 0x7f, .a = 0xff });
    const pos = coordn2srl(.{ 0, 0 });
    const text_size = rl.MeasureText("Restart", 15);
    rl.DrawText("Restart", @as(c_int, @intFromFloat(pos.x)) - @divTrunc(text_size, 2), @intFromFloat(pos.y), 15, rl.WHITE);
}

pub var dt: f32 = 0;
var et: f64 = 0;

var thrust_player = AnimationPlayer{ .anim = &Assets.Anims.thrust, .spd = 2 };
var item_water = Item{ .tex = &Assets.Texs.weapon_1 };

var c_alloc: std.mem.Allocator = undefined;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    c_alloc = gpa.allocator();

    randGen = std.rand.DefaultPrng.init(@intCast(std.time.microTimestamp()));
    rl.InitWindow(screenw, screenh, "Deep Space Rouge");
    rl.SetTargetFPS(144);
    rl.SetTraceLogLevel(rl.LOG_ERROR);
    defer rl.CloseWindow();

    Assets.load();
    defer Assets.unload();

    player.weapons = Player.Weapons.init(c_alloc);
    items = Items.init(c_alloc);
    defer {
        var ct: usize = 0;
        var it = items.iterator();
        while (it.next()) |entry| : (ct += 1) {
            const item = entry.value_ptr;
            switch (item.type) {
                .Weapon => |w| {
                    w.shoots.deinit();
                    w.onhits.deinit();
                },
                else => {},
            }
        }
        items.deinit();
        player.weapons.deinit();
    }
    try items.put(item_id, Item.machine_gun());

    _ = tryPlaceItem(.{ 0, 0 }, items.getPtr(0).?);
    Spawner.SpawnItem();
    CalItem();

    Annouce("GAME START!", 5);
    while (!rl.WindowShouldClose()) {
        var aa = std.heap.ArenaAllocator.init(c_alloc);
        defer aa.deinit();
        if (!paused) {
            dt = rl.GetFrameTime();
            et = rl.GetTime();
        } else {
            dt = 0;
        }

        // std.log.debug("t: {}", .{t});
        var pm = &player.mover;
        rl.BeginDrawing();
        {
            // rl.ClearBackground(BgColor);
            const space_tex = &Assets.Texs.space;
            rl.DrawTexturePro(space_tex.*, .{ .x = 0, .y = 0, .width = @floatFromInt(space_tex.width), .height = @floatFromInt(space_tex.height) }, .{ .x = 0, .y = 0, .width = screenw, .height = screenh }, .{ .x = 0, .y = 0 }, 0, .{ .r = 0x9f, .g = 0x9f, .b = 0x9f, .a = 0xff });
            player.dead = player.dead or player.hp <= 0;
            if (rl.IsKeyPressed(rl.KEY_R)) {
                player = Player{};
            }
            if (!player.dead) {

                // const turn_acc 	 = TurnFromKey() * t * pm.turn_acc_rate;
                pm.turn_spd *= 1 - pm.turn_spd_decay_b * dt;
                if (rl.IsKeyDown(rl.KEY_RIGHT)) {
                    pm.turn_spd = 1 * dt * pm.max_turn_spd_b;
                } else if (rl.IsKeyDown(rl.KEY_LEFT)) {
                    pm.turn_spd = -1 * dt * pm.max_turn_spd_b;
                }

                if (rl.IsKeyDown(rl.KEY_UP)) {
                    pm.foward();
                    DrawTexture(thrust_player.play(dt).*, pm.pos - v2rot(up, pm.turn) * splat(0.6 * player.size[1]), null, pm.turn);
                }
                pm.move();
                pm.pos = roundAbout(pm.pos);
                player.hp = @min(player.hp + player.hp_gen * dt, player.max_hp);
                player.mana = @min(player.mana + player.mana_gen * dt, player.max_mana);

                DrawTexture(Assets.Texs.fighter, pm.pos, null, pm.turn);
                if (rl.IsKeyDown(rl.KEY_SPACE)) {
                    const player_pos = pm.pos;
                    const wp_ct = player.weapons.items.len;
                    // -0.2 - 0.2
                    const player_w = player.size[0];
                    const interval = player_w / @as(f32, @floatFromInt(wp_ct + 1));
                    for (player.weapons.items, 0..) |*w, i| {
                        pm.pos = player_pos + v2rot(Vec2{ -player_w / 2 + @as(f32, @floatFromInt(i + 1)) * interval, 0 }, pm.turn);
                        w.ShootFoward(pm);
                    }
                    pm.pos = player_pos;
                }
                if (rl.IsKeyPressed(rl.KEY_A)) {
                    spawnAsteriod();
                }
                if (rl.IsKeyPressed(rl.KEY_S)) {
                    Spawner.SpawnWave();
                }
                if (rl.IsKeyPressed(rl.KEY_D)) {
                    debug = !debug;
                }
                if (rl.IsKeyPressed(rl.KEY_I)) {
                    paused = !paused;
                }
                if (rl.IsKeyPressed(rl.KEY_LEFT_SHIFT)) {
                    const mouse_pos = rl.GetMousePosition();
                    pm.turn_spd = 0;
                    pm.turn = 0;

                    pm.spd = .{ 0, 0 };
                    pm.pos = srl2coord(mouse_pos);
                }
            }

            testHits(&bullets, &enemies, .Enemy, false);
            testHits(&bullets, &asteriods, .Asteriod, false);

            for (&bullets) |*b| {
                if (!b.valid) continue;

                if (b.dead) {
                    playDeadAnim(b);
                } else {
                    const m = &b.mover;
                    m.move();
                    DrawTexture(b.tex.?.*, m.pos, null, m.turn);
                }
            }
            for (&ebullets) |*b| {
                if (!b.valid) continue;

                if (b.dead) {
                    playDeadAnim(b);
                } else {
                    testHit(b, &player, .Player, true);
                    const m = &b.mover;
                    m.move();
                    DrawTexture(b.tex.?.*, m.pos, null, m.turn);
                }
            }
            testCollides(&asteriods, &enemies, true);
            testCollideSelf(&asteriods);
            for (&asteriods) |*a| {
                if (!a.valid) continue;
                if (a.hp <= 0) a.dead = true;
                const m = &a.mover;
                testCollide(a, &player, true);
                m.move();
                if (a.dead) {
                    playDeadAnim(a);
                } else {
                    const tex = a.tex.?;
                    DrawTexture(tex.*, m.pos, a.size, m.turn);
                }
            }
            testCollideSelf(&enemies);

            for (&enemies) |*e| {
                if (!e.valid) continue;
                const m = &e.mover;

                if (e.hp <= 0) {
                    if (!e.dead) {
                        Gem.spawnGem(e.worth, m.pos);
                        rl.PlaySound(Assets.Sounds.explode_1);
                        Spawner.wave_left -= 1;
                    }
                    e.dead = true;
                }
                const tex = e.tex.?;
                const hole_rot = m.turn + rl.PI / 2;
                const hole_pos = m.pos + v2rot(.{ 0.15, 0 }, hole_rot);
                if (!e.warmhole_player.isLast()) {
                    const worm_tex = e.warmhole_player.play(dt);
                    DrawTexture(worm_tex.*, hole_pos, null, hole_rot);
                    if (e.warmhole_player.curr_frame >= 16) {
                        const ratio = @as(f32, @floatFromInt(e.warmhole_player.curr_frame)) / @as(f32, @floatFromInt(e.warmhole_player.anim.frames.items.len));
                        const c: u8 = @intFromFloat(ratio * ratio * 255);
                        const tint = rl.Color{ .r = c, .g = c, .b = c, .a = c };
                        const lerp_pos = v2lerp(hole_pos, m.pos, @log2(ratio + 1));
                        DrawTextureTint(tex.*, lerp_pos, null, m.turn, tint);
                    }
                    continue;
                }

                if (e.dead) {
                    if (!e.explode_player.isLast()) {
                        DrawTexture(e.explode_player.play(dt).*, m.pos, null, m.turn);
                    } else {
                        e.tex = null;
                        e.valid = false;
                    }
                } else {
                    testCollide(e, &player, true);
                    if (e.ai) |ai| ai(e);
                    DrawTexture(tex.*, m.pos, null, m.turn);
                }
            }
            for (&gems) |*g| {
                if (!g.valid) continue;
                const gm = &g.mover;
                const dist = v2dist(gm.pos, pm.pos);
                if (dist < 0.1) {
                    g.valid = false;
                    player.gems += Gem.Values[g.lvl];
                    const i = randGen.next() % 3;
                    const sound = switch (i) {
                        0 => &Assets.Sounds.gem_pickup_1,
                        1 => &Assets.Sounds.gem_pickup_2,
                        2 => &Assets.Sounds.gem_pickup_3,
                        else => unreachable,
                    };
                    rl.PlaySound(sound.*);
                }
                if (dist < 0.4) {
                    gm.spd += v2n(pm.pos - gm.pos) * splat(gm.acc_rate_b * gm.acc_rate_m * dt);
                }
                gm.move();
                gm.pos = roundAbout(gm.pos);
                DrawTexture(Gem.Texs[g.lvl].*, gm.pos, null, gm.turn);
            }
            if (player.gems >= next_lvl_gems) {
                player.gems -= next_lvl_gems;
                next_lvl_gems = next_lvl_gems + 50;
                rl.PlaySound(Assets.Sounds.level_up);
                Annouce("Level Up! (Open Inventory With [I])", 2);
                Spawner.SpawnItem();
            }

            // for (&anims) |a| {
            // 	if (!a.valid) continue;
            // 	const tex = a.play(t);

            // }
            if (paused) DrawItemMenu();
            DrawHUD();
            if (player.dead) DrawRestart();
            const dir = v2rot(up, pm.turn);
            if (debug)
                rl.DrawLineV(coordn2srl(pm.pos), coordn2srl(pm.pos + dir), rl.RED);

            if (Spawner.wave_left == 0) {
                Spawner.SpawnWave();
                Spawner.wave_worth += 30;
                Spawner.wave_ct += 1;
            }
            if (annouce_t > 0) {
                annouce_t -= dt;
                const tw = rl.MeasureText(annoucement, 25);
                rl.DrawText(annoucement, @divFloor(-tw + screenw, 2), 50, 25, rl.LIGHTGRAY);
            }
        }

        rl.EndDrawing();
    }
}

// pub fn dmage(dmg: f32) (fn () f32) {
// 	return struct {
// 		pub fn impl() f32 {
// 			return dmg;
// 		}
// 	}.impl;
// }
// test "capture" {
// 	const f = dmage(5);
// 	try std.testing.expect(f() == 5);
// }
