const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");

const Assets = @This();
pub const assetsDir = "assets/";
pub const Anims = struct {
    pub var asteroid:       Animation = undefined;
    pub var thrust:         Animation = undefined;
    pub var wormhole:       Animation = undefined;
    pub var explode_blue:   Animation = undefined;
    pub var bullet_hit:     Animation = undefined;
    pub fn load() void {
    
        const info = @typeInfo(Anims).Struct;
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
        const info = @typeInfo(Anims).Struct;
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            @field(Anims, d.name).deinit();

            
        }
    }
};

pub const Texs = struct {
    pub var space:             rl.Texture2D = undefined;
    
    pub var fighter:        rl.Texture2D = undefined;
    pub var bullet:         rl.Texture2D = undefined;
    pub var asteroid:       rl.Texture2D = undefined;
    // pub var enemy: rl.Texture2D = undefined;

    pub var bullet_fire:    rl.Texture2D = undefined;
    pub var hunter:         rl.Texture2D = undefined;
    pub var crasher:        rl.Texture2D = undefined;

    pub var gem_1:          rl.Texture2D = undefined;
    pub var gem_2:          rl.Texture2D = undefined;
    pub var gem_3:          rl.Texture2D = undefined;

    pub var block:          rl.Texture2D = undefined;
    pub fn load() void {
        const info = @typeInfo(Texs).Struct;
        inline for (info.decls) |d| {
            if (comptime std.mem.eql(u8, "load", d.name) or std.mem.eql(u8, "unload", d.name)) continue;
            // std.log.debug("{any}", .{@field(Texs, d.name)});
            var path: [d.name.len+4:0]u8 = undefined;
            @memcpy(path[0..d.name.len], d.name);
            @memcpy(path[d.name.len..], ".png");
            @field(Texs, d.name) = rl.LoadTexture(assetsDir ++ path);
            if (@field(Texs, d.name).id <= 0) {
                std.log.err("failed to load texture: {s}", .{assetsDir ++ path});
            }
            
        }
    }
    pub fn unload() void {
        const info = @typeInfo(Texs).Struct;
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
    pub var bullet_hit:     rl.Sound = undefined;
    pub var level_up:       rl.Sound = undefined;
    pub var collide:        rl.Sound = undefined;
    pub var explode_1:      rl.Sound = undefined;
    pub fn load() void {
        const info = @typeInfo(Sounds).Struct;
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
        const info = @typeInfo(Sounds).Struct;
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


	// pub fn init() Assets {
	// 	const info = @typeInfo(Assets).Struct;
	// 	var assets: Assets = undefined;
	// 	inline for (info.fields) |f| {
	// 		if (f.type == Animation) {
	// 			const path = f.name[0..];
	// 		} else if (f.type == rl.Texture2D) {

	// 		} else unreachable;
	// 	}
	// 	return assets;
	// }


pub const Frames = std.ArrayList(rl.Texture2D);
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
pub const AnimationPlayer = struct {
	spd: f32 = 10,
	curr_frame: usize = 0,
	et: f32 = 0,
	anim: *Animation,
	loop: bool = false,
	valid: bool = false,
	size: ?@Vector(2, f32) = null,
	pub fn play(self: *AnimationPlayer, t: f32) *rl.Texture2D {
		self.et += t;
		if (self.et >= 1/self.spd) {
			self.curr_frame = (self.curr_frame + 1) % self.anim.frames.items.len;
			self.et = 0;
		}
		return &self.anim.frames.items[self.curr_frame];
	}
	pub fn isLast(self: AnimationPlayer) bool {
		return self.curr_frame >= self.anim.frames.items.len - 1;
	}
	pub fn last(self: AnimationPlayer) usize {
		return self.anim.frames.items.lenm;
	}
};