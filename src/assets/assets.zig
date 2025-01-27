const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");

const Assets = @This();
//const m = @import("math.zig");
pub const assetsDir = "assets/";
pub const Anims = struct {
    pub var asteroid:       Animation = undefined;
    pub var thrust:         Animation = undefined;
    pub var wormhole:       Animation = undefined;
    pub var explode_blue:   Animation = undefined;
    pub var bullet_hit:     Animation = undefined;
    pub fn load() void {
    
        const info = @typeInfo(Anims).@"struct";
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            var path: [d.name.len+4:0]u8 = undefined;
            @memcpy(path[0..d.name.len], d.name);
            @memcpy(path[d.name.len..path.len], ".gif");
            @field(Anims, d.name) = Animation.init(assetsDir ++ path, std.heap.c_allocator);
            if (@field(Anims, d.name).frames.items.len == 0) {
                std.log.err("failed to load Anims: {s}", .{assetsDir ++ path});
            }
            
        }
    }
    pub fn unload() void {
        const info = @typeInfo(Anims).@"struct";
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            @field(Anims, d.name).deinit();

            
        }
    }
};

pub const Texs = struct {
    pub var space:          rl.Texture = undefined;
    
    pub var fighter:        rl.Texture = undefined;
    pub var carrier:        rl.Texture = undefined;
    pub var turret:         rl.Texture = undefined;
    pub var turret_item:    rl.Texture = undefined;
    pub var bullet:         rl.Texture = undefined;
    pub var bullet_2:       rl.Texture = undefined;
    pub var asteroid:       rl.Texture = undefined;
    // pub var enemy: rl.Texture = undefined;

    pub var bullet_fire:    rl.Texture = undefined;
    pub var hunter:         rl.Texture = undefined;
    pub var crasher:        rl.Texture = undefined;

    pub var gem_1:          rl.Texture = undefined;
    pub var gem_2:          rl.Texture = undefined;
    pub var gem_3:          rl.Texture = undefined;

    pub var block:          rl.Texture = undefined;
    pub var water:          rl.Texture = undefined;
    pub var weapon_1:       rl.Texture = undefined;
    pub var machine_gun:    rl.Texture = undefined;
    pub var missile:        rl.Texture = undefined;
    pub var torpedo:        rl.Texture = undefined;
    pub var power_shot:     rl.Texture = undefined;
    pub var weight:         rl.Texture = undefined;
    pub var triple_shots:   rl.Texture = undefined;
    pub var energy_bullet:  rl.Texture = undefined;
    pub fn load() void {
        const info = @typeInfo(Texs).@"struct";
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            //var path: [d.name.len+4:0]u8 = undefined;
            //@memcpy(path[0..d.name.len], d.name);
            //@memcpy(path[d.name.len..], ".png");
            const path = "../" ++ assetsDir ++ d.name ++ ".png";
            const raw = @embedFile(path);
            const image = rl.LoadImageFromMemory(".png", raw, raw.len);
            @field(Texs, d.name) = rl.LoadTextureFromImage(image);
            //@field(Texs, d.name) = rl.LoadTexture(assetsDir ++ path);
            if (@field(Texs, d.name).id <= 0) {
                std.log.err("failed to load texture: {s}", .{assetsDir ++ path});
            }
            
        }
    }
    pub fn unload() void {
        const info = @typeInfo(Texs).@"struct";
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            rl.UnloadTexture(@field(Texs, d.name) );

        }
    }
};
pub const Sounds = struct {
    pub const dir  = assetsDir ++ "sound/";

    pub var gem_pickup_1:   rl.Sound = undefined;
    pub var gem_pickup_2:   rl.Sound = undefined;
    pub var gem_pickup_3:   rl.Sound = undefined;
    pub var shoot:          rl.Sound = undefined;
    pub var shoot2:         rl.Sound = undefined;
    pub var bullet_hit:     rl.Sound = undefined;
    pub var bullet_hit_2:     rl.Sound = undefined;
    pub var level_up:       rl.Sound = undefined;
    pub var collide:        rl.Sound = undefined;
    pub var explode_1:      rl.Sound = undefined;
    pub var explode_2:      rl.Sound = undefined;
    pub var hurt:           rl.Sound = undefined;
    pub var select:         rl.Sound = undefined;
    pub fn load() void {
        const info = @typeInfo(Sounds).@"struct";
        rl.InitAudioDevice();
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name) or std.mem.eql(u8, "dir", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            var path: [d.name.len+4:0]u8 = undefined;
            @memcpy(path[0..d.name.len], d.name);
            @memcpy(path[d.name.len..], ".wav");
            @field(Sounds, d.name) = rl.LoadSound(dir ++ path);
            if (@field(Sounds, d.name).frameCount <= 0) {
                std.log.err("failed to load Sound: {s}", .{dir ++ path});
            }
            
        }
    }
    pub fn unload() void {
        const info = @typeInfo(Sounds).@"struct";
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name) or std.mem.eql(u8, "dir", d.name)) continue;
            rl.UnloadSound(@field(Sounds, d.name) );

        }
        rl.CloseAudioDevice();
    }
};

pub fn load() void {
    Texs.load();
    Anims.load();
    Sounds.load();
}
pub fn unload() void {
    Texs.unload();
    Anims.unload();
    Sounds.unload();
}



pub const Frames = std.ArrayList(rl.Texture);
pub const Animation = struct {
	frames: Frames,
	img: rl.Image,
	pub fn init(path: [:0]const u8, allocator: std.mem.Allocator) Animation {
		var total_frame_ct: usize = 0;
		var res = Animation {.frames = Frames.init(allocator), .img = rl.LoadImageAnim(@ptrCast(path), @ptrCast(&total_frame_ct))};
		for (0..total_frame_ct) |i| {
			const off = @as(usize, @intCast(res.img.width*res.img.height))*4*i;
			const tex = rl.LoadTextureFromImage(res.img);
			const data: [*]u8 = @ptrCast(res.img.data orelse @panic(path));
			rl.UpdateTexture(tex, data + off);
			res.frames.append(tex) catch unreachable;
		}
		return res;
		
	}
	pub fn deinit(self: *Animation) void {
		for (self.frames.items) |t| {
			rl.UnloadTexture(t);
		}
		rl.UnloadImage(self.img);
		self.frames.deinit();
	}

};

