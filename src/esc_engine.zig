
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Entity = u32;
pub fn Signature(comptime comp_types: []const type) type {
    return std.bit_set.IntegerBitSet(comp_types.len);
}

pub fn ComponentManager(comptime comp_types: []const type) type {
    const SelfSig = Signature(comp_types);
    return struct {
        const Self = @This();
        fn CompArrs() type {
            var arrs: [comp_types.len]type = undefined;
            for (comp_types, &arrs) |t, *at| {
                at.* = ComponentArray(t);
            }
            return std.meta.Tuple(&arrs);
            // const info = std.builtin.Type {.@"struct" =};
        }
        pub fn sig_from_types(comptime ts: []const type) SelfSig {
            var sig = SelfSig.initEmpty();
            for (ts) |t| {
                for (comp_types, 0..) |t2, i| {
                    if (t == t2) {
                        sig.set(i);
                    }
                }
            }
            return sig;
        }
        comp_arrs: CompArrs(),
        pub fn type_to_bit(comptime T: type) usize {
            inline for (comp_types, 0..) |t, i| {
                if (T == t) return i;
            }
            @panic("Component type is not registered");
        }
        pub fn init(a: Allocator) Self {
            var res = Self {.comp_arrs = undefined};
            inline for (&res.comp_arrs) |*arr| {
                arr.* = @TypeOf(arr.*).init(a);
            }
            return res;
        }
        pub fn add(self: *Self, e: Entity, comp: anytype) void {
            const T = @TypeOf(comp);
            const comp_arr = self.get_arr(T);
            comp_arr.add(e, comp);
        }
        pub fn delete(self: *Self, e: Entity, comptime T: type) void {
            const comp_arr = self.get_arr(T);
            comp_arr.delete(e);
        }
        pub fn delete_entity(self: *Self, e: Entity) void {
            inline for (comp_types) |t| {
                self.delete(e, t);
            }
        }
        fn get_idx(comptime T: type) usize {
            inline for (comp_types, 0..) |t, i| {
                if (t == T) return i;
            }
            @compileError("ComponentArray of type '" ++ @typeName(T) ++ "'is not registered");

        }
        pub fn get_arr(self: *Self, comptime T: type) *ComponentArray(T) {
            return &self.comp_arrs[comptime get_idx(T)];
        }
        // pub fn register(self: *Self, arr: anytype) void {
        //     const T = @TypeOf(arr);
        //     const info = @typeInfo(T);
        //     switch (info) {
        //         .ptr => |_| {
        //             self.comp_arrs.putNoClobber(T, @ptrCast(arr));
        //         },
        //         else => @compileError("arr must be a a pointer to ComponentArray"),
        //     }
        // }
        pub fn get_comp(self: *Self, comptime T: type, e: Entity) ?*T {
            const comp_arr = self.get_arr(T);
            return comp_arr.get(e);
        }
        pub fn deinit(self: *Self) void {
            // return self.comp_arrs.de;
            inline for (comp_types) |t| {
                const arr = self.get_arr(t);
                arr.deinit();
            }
        } 
    };
}
pub fn ComponentArray(comptime T: type) type {
    return struct {
        const MAX_COMP = 512;
        const Self = @This();
        comps: std.BoundedArray(T, MAX_COMP),
        entity_to_comp: std.AutoHashMap(Entity, usize),
        comp_to_entity: std.AutoHashMap(usize, Entity),


        pub fn init(a: Allocator) @This() {
            return .{
                .comps = std.BoundedArray(T, MAX_COMP).init(0) catch unreachable,
                .entity_to_comp = std.AutoHashMap(Entity, usize).init(a),
                .comp_to_entity = std.AutoHashMap(usize, Entity).init(a),
            };
        }
        pub fn deinit(self: *Self) void {
            self.entity_to_comp.deinit();
            self.comp_to_entity.deinit();
        }
        pub fn clear(self: *Self) void {
            self.comps.clear();
            self.entity_to_comp.clearRetainingCapacity();
            self.comp_to_entity.clearRetainingCapacity();
        }
        pub fn add(self: *Self, e: Entity, comp: T) void {
            assert(self.comps.len != self.comps.capacity());
            const gop = self.entity_to_comp.getOrPut(e) catch unreachable;
            if (!gop.found_existing) {
                gop.value_ptr.* = self.comps.len;
                self.comp_to_entity.putNoClobber(self.comps.len, e) catch unreachable;
                self.comps.append(comp) catch unreachable;
            }

        }
        // does nothing if entity does not exist
        pub fn delete(self: *Self, e: Entity) void {
            if (self.comps.len == 0) return;
            const comp_idx = (self.entity_to_comp.fetchRemove(e) orelse return).value;
            // if (self.comps.len )
            const last_idx = self.comps.len - 1;
            const last_entity = (self.comp_to_entity.fetchRemove(last_idx) orelse unreachable).value;

            // swap
            _ = self.comps.swapRemove(comp_idx);
            if (comp_idx != last_idx) {
                self.entity_to_comp.put(last_entity, comp_idx) catch unreachable;
                self.comp_to_entity.put(comp_idx, last_entity) catch unreachable;
            }
        }
        pub fn get(self: *Self, e: Entity) ?*T {
            const idx = self.entity_to_comp.get(e) orelse return null;
            return &self.comps.slice()[idx];
        }
    };
}




pub fn System(comptime comp_types: []const type) type {
    return struct {
        const Self = @This();
        entities: []std.AutoHashMap(Entity, void),
        ptr: *anyopaque,
        set: []const Signature(comp_types),
        update_fn: *const fn(ptr: *anyopaque, entities: []const std.AutoHashMap(Entity, void), dt: f32) void,

        pub fn update(self: Self, dt: f32) void {
            self.update_fn(self.ptr, self.entities, dt);
        }
    };
}
pub fn SystemManager(comptime comp_types: []const type, comptime even_types: []const type) type {
    return struct {
        const Self = @This();
        const MAX_ENTITIES = 1024;
        const event_sig = blk: {
            var sig = Signature(comp_types).initEmpty();
            for (even_types) |t| {
                sig.set(ComponentManager(comp_types).type_to_bit(t));
            }
            break :blk sig;
        };
        systems: std.ArrayList(System(comp_types)),
        fresh_entities: std.BoundedArray(Entity, MAX_ENTITIES),
        signatures: [MAX_ENTITIES]Signature(comp_types),
        comp_man: ComponentManager(comp_types),
        pub fn init(a: Allocator) Self {
            var res = Self {
                .systems = std.ArrayList(System(comp_types)).init(a), 
                .fresh_entities = std.BoundedArray(Entity, MAX_ENTITIES).init(0) catch unreachable, 
                .signatures = undefined,
                .comp_man = ComponentManager(comp_types).init(a),

            };
            for (0..MAX_ENTITIES) |e| {
                res.fresh_entities.append(@intCast(e)) catch unreachable;
            }
            return res;
        }
        pub fn deinit(self: *Self) void {
            for (self.systems.items) |*sys| {
                for (sys.entities) |*es| {
                    es.deinit();
                }
                self.systems.allocator.free(sys.entities);
            }
            self.systems.deinit();
            self.comp_man.deinit();

        }
        pub fn register(self: *Self, sys: System(comp_types)) void {
            self.systems.append(sys) catch unreachable;
        }
        pub fn new_entity(self: *Self) Entity {
            const e: Entity = self.fresh_entities.popOrNull() orelse @panic("reach maximum entity");
            self.signatures[e] = Signature(comp_types).initEmpty();
            return e;
        }
        pub fn free_entity(self: *Self, e: Entity) void {
            self.signatures[e] = Signature(comp_types).initEmpty();
            self.update_comp(e);
            // for (self.systems.items, 0..) |sys, i| {
            //     std.log.debug("free {} {}", .{i, sys.entities.count()});
            // }
            self.fresh_entities.append(e) catch unreachable;
            self.comp_man.delete_entity(e);
        }
        pub fn add_comp(self: *Self, e: Entity, comp: anytype) void {
            const T = @TypeOf(comp);
            self.comp_man.add(e, comp);
            self.signatures[e].set(ComponentManager(comp_types).type_to_bit(T));
            self.update_comp(e);
        }
        pub fn add_comp2(self: *Self, e: Entity, comp: anytype) void {
            const T = @TypeOf(comp);
            self.comp_man.add(e, comp);
            self.signatures[e].set(ComponentManager(comp_types).type_to_bit(T));
            self.update_comp2(e);
        }
        pub fn del_comp(self: *Self, e: Entity, comptime T: type) void {
            self.comp_man.delete(e, T);
            self.signatures[e].unset(ComponentManager(comp_types).type_to_bit(T));
            self.update_comp(e);
        }
        pub fn clear_events(self: *Self) void {
            const empty = Signature(comp_types).initEmpty();
            inline for (even_types) |t| {
                self.comp_man.get_arr(t).clear();
            }
            for (self.systems.items) |*sys| {
                for (sys.entities, sys.set) |*es, set| {
                    if (!set.intersectWith(event_sig).eql(empty)) {
                        es.clearRetainingCapacity();
                    }
                }
                
            }
        }
        pub fn clear_all(self: *Self) void {
            for (self.systems.items) |*sys| {
                for (sys.entities) |*es| {
                    es.clearRetainingCapacity();
                }
            }
            self.fresh_entities.clear();
            for (0..MAX_ENTITIES) |e| {
                self.fresh_entities.append(@intCast(e)) catch unreachable;
            }
            inline for (comp_types) |t| {
                self.comp_man.get_arr(t).clear();
            }
        }
        // iterate through all registered systems, and check if the entity should be in system
        fn update_comp(self: *Self, e: Entity) void {
            const sig = self.signatures[e];
            for (self.systems.items) |*sys| {
                for (sys.entities, sys.set) |*es, set| {
                    if (set.subsetOf(sig)) {
                        _ = es.getKey(e) orelse { es.put(e, void{}) catch unreachable;};
                    } else {
                        _ = es.remove(e);
                    }
                }
            }
        }

        pub fn update(self: *Self, dt: f32) void {
            for (self.systems.items) |sys| {
                sys.update(dt);
            }
        }

    };
}



