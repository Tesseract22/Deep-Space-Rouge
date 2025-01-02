const m = @import("math.zig");
const utils = @import("utils.zig");
const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Vec2 = m.Vec2;
pub const Particle = struct {
    pos: Vec2,
    vel: Vec2,
    color: rl.Color = rl.WHITE,
    t: f32,
    max_t: f32,
};
pub const Entity = u32;
pub const MAX_PARTICLE = 1024;
pub var buffer = std.BoundedArray(Particle, MAX_PARTICLE).init(0) catch unreachable;


// find a new slot in the buffer, evict old particle if full
pub fn new_particle() Entity {
    if (buffer.len == buffer.capacity()) {
        return 0;
    }
    defer buffer.len += 1;
    return @intCast(buffer.len);
}
pub fn emit_random(pos: Vec2) void {
    emit(pos, 0.2, 5, m.rand_color());
    
}
pub fn emit(pos: Vec2, vel_range: f32, t: f32, color: rl.Color) void {
    const e = new_particle();
    const p = &buffer.slice()[e];
    const rot =  m.rand_rot();
    p.max_t = t;
    p.t = t;
    p.pos = pos;
    p.vel = m.v2rot(m.Vec2 {0, m.randf(0, vel_range) }, rot);
    p.color = color;
    
}
pub fn update(dt: f32) void {
    var i: usize = 0;
    while (i < buffer.len) {
        const p = &buffer.slice()[i];
        //std.log.debug("particle update {}", .{i});
        p.pos += p.vel * m.splat(dt);
        var color = p.color;
        color.a = @intFromFloat(@as(f32, @floatFromInt(color.a)) * p.t / p.max_t);
        utils.DrawRectCentered(p.pos, .{0.01, 0.01}, color);
        p.t -= dt;
        if (p.t < 0) {
            _ = buffer.swapRemove(i);
        } else {
            i += 1;
        }
    }
}
