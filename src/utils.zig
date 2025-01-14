const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const m = @import("math.zig");
const Vec2 = m.Vec2;

const conf = @import("config.zig");

fn MeasureTex(tex: rl.Texture2D) rl.Vector2 {
    return .{ .x = @as(f32, @floatFromInt(tex.width)) * conf.pixelMul, .y = @as(f32, @floatFromInt(tex.height)) * conf.pixelMul };
}

pub inline fn DrawTexture(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32) void {
    DrawTextureTint(tex, origin, size, rot, rl.WHITE);
}

pub fn DrawTextureTint(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32, tint: rl.Color) void {
    const pos = m.coordn2srl(origin);
    const tw: f32 = @floatFromInt(tex.width);
    const th: f32 = @floatFromInt(tex.height);
    var dw: f32 = 0;
    var dh: f32 = 0;
    if (size) |s| {
        const dest = m.sizen2srl(s);
        dw = dest.x;
        dh = dest.y;
    } else {
        dw = tw * conf.pixelMul;
        dh = th * conf.pixelMul;
    }
    rl.DrawTexturePro(tex, .{ .x = 0, .y = 0, .width = tw, .height = th }, .{ .x = pos.x, .y = pos.y, .width = dw, .height = dh }, .{ .x = dw / 2, .y = dh / 2 }, rot / rl.PI * 180.0, tint);
    if (conf.debug)
        rl.DrawCircleLinesV(pos, @max(dw, dh) / 2, rl.RED); // debug

}

pub inline fn DrawRectCentered(pos: Vec2, size: Vec2, c: rl.Color) void {
    rl.DrawRectangleV(m.coordn2srl(pos - size / m.splat(2.0)), m.sizen2srl(size), c);
}

pub fn DrawText(v: m.Vec2, text: [:0]const u8, font_size: u8, color: rl.Color) void {
    const pos = m.coordn2srl(v);
    rl.DrawText(text, @intFromFloat(pos.x), @intFromFloat(pos.y), font_size, color);
}


pub inline fn DrawTexture_static(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32) void {
    DrawTextureTint_static(tex, origin, size, rot, rl.WHITE);
}

pub fn DrawTextureTint_static(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32, tint: rl.Color) void {
    const pos = m.coordn2srl_static(origin);
    const tw: f32 = @floatFromInt(tex.width);
    const th: f32 = @floatFromInt(tex.height);
    var dw: f32 = 0;
    var dh: f32 = 0;
    if (size) |s| {
        const dest = m.sizen2srl_static(s);
        dw = dest.x;
        dh = dest.y;
    } else {
        dw = tw * conf.pixelMul;
        dh = th * conf.pixelMul;
    }
    rl.DrawTexturePro(tex, .{ .x = 0, .y = 0, .width = tw, .height = th }, .{ .x = pos.x, .y = pos.y, .width = dw, .height = dh }, .{ .x = dw / 2, .y = dh / 2 }, rot / rl.PI * 180.0, tint);
    if (conf.debug)
        rl.DrawCircleLinesV(pos, @max(dw, dh) / 2, rl.RED); // debug

}

pub inline fn DrawRectCentered_static(pos: Vec2, size: Vec2, c: rl.Color) void {
    rl.DrawRectangleV(m.coordn2srl_static(pos - size / m.splat(2.0)), m.sizen2srl_static(size), c);
}

pub fn DrawText_static(v: m.Vec2, text: [:0]const u8, font_size: u8, color: rl.Color) void {
    const pos = m.coordn2srl_static(v);
    rl.DrawText(text, @intFromFloat(pos.x), @intFromFloat(pos.y), font_size, color);
}


