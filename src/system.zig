const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const esc = @import("esc_engine.zig");
const Entity = esc.Entity;

const comp = @import("componet.zig");
const CompMan = comp.Manager;
const Signature = esc.Signature(&comp.comp_types);
const System = esc.System(&comp.comp_types);

const m = @import("math.zig");
const Vec2 = m.Vec2;

const conf = @import("config.zig");
const utils = @import("utils.zig");

pub const Manager = esc.SystemManager(&comp.comp_types);
pub var syss: Manager = undefined;

// ------------------------ System Implementation ------------------------
pub const Physic = struct {
    pub const set = Signature.initEmpty();
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            vel.vel *= m.splat(1 - vel.drag * dt);
            vel.rot *= 1 - vel.rot_drag * dt;
            pos.pos += vel.vel * m.splat(dt);
            pos.rot += vel.rot;
            
            pos.pos = m.round_about(pos.pos);
            // std.log.debug("entity: {} {}", .{e, pos.pos});
        }
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};

pub const View = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.View});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        //std.log.debug("View System update", .{});
        //std.log.debug("entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const view = syss.comp_man.get_comp(comp.View, e) orelse unreachable;

            utils.DrawTexture(view.*.*, pos.pos, null, pos.rot);
            // rl.DrawCircleV(m.coordn2srl(pos.pos), view.radius, rl.WHITE)
            // std.log.debug("entity: {} {} {}", .{e, pos.pos, view.radius});
        }
        _ = self;
        _ = dt;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};
pub const Input = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Input, comp.ShipControl});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const input = syss.comp_man.get_comp(comp.Input, e) orelse unreachable;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            control.reset_state();
            const state = &control.state;
            const d = rl.IsKeyDown;

            if (d(input.left)) state.turn = .counter;
            if (d(input.right)) state.turn = .clock;
            if (d(input.forward)) state.forward = true;
            if (d(input.backward)) state.brake = true;
            // if (d(input.shoot)) state. = true;
        }
        _ = self;
        _ = dt;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};


pub const ShipControl = struct {
    pub const set = CompMan.sig_from_types(&.{comp.Pos, comp.Vel, comp.ShipControl});
    pub fn update(ptr: *anyopaque, entities: *const std.AutoHashMap(Entity, void), dt: f32) void {
        const self: *@This() = @ptrCast(ptr);
        // std.log.debug("Physic System update", .{});
        // std.log.debug("entities: {}", .{entities.count()});
        var it = entities.iterator();
        while (it.next()) |entry| {
            const e = entry.key_ptr.*;
            const vel = syss.comp_man.get_comp(comp.Vel, e) orelse unreachable;
            const control = syss.comp_man.get_comp(comp.ShipControl, e) orelse unreachable;
            const state = &control.state;
            const pos = syss.comp_man.get_comp(comp.Pos, e) orelse unreachable;
            const rot_acc: f32 = switch (state.turn) {
                .clock => 1,
                .counter => -1,
                .static => 0,
            };
            vel.rot += rot_acc * control.turn_thurst * dt;
            if (state.forward) {
                vel.vel += m.v2rot(m.up, pos.rot) * m.splat(control.thurst * dt);
            } else if (state.brake) {
                vel.vel *= m.splat(1 - control.brake_rate * dt);
            }
            // std.log.debug("entity: {} {}", .{e, pos.pos});
        }
        _ = self;
    }
    pub fn system(self: *@This(), a: Allocator) System {
        return .{
            .entities = std.AutoHashMap(Entity, void).init(a),
            .ptr = @alignCast(@ptrCast(self)),
            .update_fn = update,
            .set = set,
        };
    }
};



