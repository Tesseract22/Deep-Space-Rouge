const rl = @cImport(@cInclude("raylib.h"));
const conf = @import("config.zig");
const std = @import("std");
const main = @import("main.zig");
pub const Vec2 = @Vector(2, f32);
pub const Vec2i = @Vector(2, c_int);


pub const screenSizef = Vec2{ conf.screenhf, conf.screenhf };
pub const up = Vec2{ 0, -1 };



// const DefaultBullet = struct {

// };
pub const Camera = struct {
    pos: Vec2 = .{0, 0},
    vel: Vec2 = .{0, 0},
    drag: f32 = 1,
    zoom: f32 = 1,
};
pub fn splat(i: f32) Vec2 {
    return @splat(i);
}
pub fn coordn2srl(v: Vec2) rl.Vector2 {
    return v2rl((v + splat(1.0 * main.camera.zoom)) / splat(2 * main.camera.zoom) * screenSizef + Vec2{ (conf.screenwf - conf.screenhf) / 2, 0.0 });
}
pub fn srl2sizen(v: rl.Vector2) Vec2 {
    return rl2v2(v) / screenSizef * splat(2 * main.camera.zoom);
}
pub fn srl2coord(v: rl.Vector2) Vec2 {
    return (rl2v2(v) - Vec2{ (conf.screenwf - conf.screenhf) / 2, 0.0 }) * splat(2 * main.camera.zoom) / screenSizef - splat(1.0 * main.camera.zoom);
}
pub fn size2s(s: f32) f32 {
    return s * screenSizef[0] * 0.5 / main.camera.zoom;
}
pub fn sizen2srl(v: Vec2) rl.Vector2 {
    return v2rl(v * screenSizef / splat(2 * main.camera.zoom));
}
// --------------------------------------------- static version ----------------------------------------

pub fn coordn2srl_static(v: Vec2) rl.Vector2 {
    return v2rl((v + splat(1.0)) / splat(2) * screenSizef + Vec2{ (conf.screenwf - conf.screenhf) / 2, 0.0 });
}
pub fn srl2sizen_static(v: rl.Vector2) Vec2 {
    return rl2v2(v) / screenSizef * splat(2);
}
pub fn s2size_static(s: usize) f32 {
    return @as(f32, @floatFromInt(s)) / conf.screenwf * 2 * conf.pixelMul;
}
pub fn srl2coord_static(v: rl.Vector2) Vec2 {
    return (rl2v2(v) - Vec2{ (conf.screenwf - conf.screenhf) / 2, 0.0 }) * splat(2) / screenSizef - splat(1.0);
}
pub fn size2s_static(s: f32) f32 {
    return s * screenSizef[0] * 0.5;
}
pub fn sizen2srl_static(v: Vec2) rl.Vector2 {
    return v2rl(v * screenSizef / splat(2));
}





pub inline fn v2rl(v: Vec2) rl.Vector2 {
    return .{ .x = v[0], .y = v[1] };
}
pub inline fn rl2v2(rlv: rl.Vector2) Vec2 {
    return .{ rlv.x, rlv.y };
}
pub inline fn v2eq0(v: Vec2) bool {
    return v[0] == 0 and v[1] == 0;
}
pub inline fn v2lerp(from: Vec2, to: Vec2, t: f32) Vec2 {
    return (to - from) * splat(t) + from;
}
pub fn v2rot(v: Vec2, rot: f32) Vec2 {
    return Vec2{ @cos(rot), @sin(rot) } * splat(v[0]) + Vec2{ -@sin(rot), @cos(rot) } * splat(v[1]);
}
pub inline fn v2len(v: Vec2) f32 {
    return @sqrt(@reduce(.Add, v * v));
}

pub inline fn v2n(v: Vec2) Vec2 {
    return v / splat(v2len(v));
}
pub inline fn v2dist(a: Vec2, b: Vec2) f32 {
    return v2len(a - b);
}
pub inline fn v2dot(a: Vec2, b: Vec2) f32 {
    return @reduce(.Add, a * b);
}
pub inline fn v2cross(a: Vec2, b: Vec2) f32 {
    return a[0] * b[1] - b[0] * a[1];
}
pub inline fn rad2deg(r: f32) f32 {
    return r * 180.0 / rl.PI;
}
pub inline fn deg2rad(d: f32) f32 {
    return d / 180 * rl.PI;
}

pub fn round_about(pos: Vec2) Vec2 {
    const screen_rang = Vec2{ 2 * conf.screenwf / conf.screenhf, 2 } * splat(conf.round_about_extra_space);
    const half = screen_rang / splat(2);
    return @mod(pos + half, screen_rang) - half;
}

pub fn diffClock(from: f32, to: f32) f32 {
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

pub var randGen: std.Random.Xoshiro256 = undefined;
pub fn randf(min: f32, max: f32) f32 {
    const range = max - min;
    return randGen.random().float(f32) * range + min;
}
pub fn randu(min: usize, max: usize) usize {
    const range = max - min;
    if (range == 0) return max;
    return randGen.random().int(usize) % range + min;
}
pub fn rand_int(comptime T: type, min: T, max: T) T {
    const range = max - min;
    if (range == 0) return max;
    return @rem(randGen.random().int(T), range) + min;
}

pub fn randSign() f32 {
    return if (randGen.random().float(f32) > 0.5) 1 else -1;
}
pub fn rand_pos() Vec2 {
    return .{ randf(-0.8, 0.8), randf(-0.8, 0.8) };
}
pub fn rand_color() rl.Color {
    return .{.r = rand_int(u8, 0, 255), .g = rand_int(u8, 0, 255), .b = rand_int(u8, 0, 255), .a = 255};
}
pub fn rand_color2(c: rl.Color, nudge: u8) rl.Color {
    var c2 = c;
    c2.r -|= rand_int(u8, 0, nudge);
    c2.g -|= rand_int(u8, 0, nudge);
    c2.b -|= rand_int(u8, 0, nudge);
    return c2;
}

pub fn rand_rot() f32 {
    return randf(0, 2*std.math.pi);
}

pub fn measure_tex(tex: rl.Texture) Vec2 {
    const v = Vec2 {@floatFromInt(tex.width), @floatFromInt(tex.height)};
    return v / screenSizef * splat(2) * splat(conf.pixelMul);
}
