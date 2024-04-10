const rl = @cImport(@cInclude("raylib.h"));
const std = @import("std");

const Vec2 = @Vector(2, f32);
const Vec2i = @Vector(2, c_int);
const BgColor = rl.Color {.r = 0x1f, .g = 0x1f, .b = 0x1f, .a = 0x1f};


const screenh = 1080;
// const screenRatio = 16.0/9.0;
const screenw = screenh * 16 / 9;

const screenhf: f32 = @floatFromInt(screenh);
const screenwf: f32 = @floatFromInt(screenw);
const screenSizef = Vec2 {@floatFromInt(screenh), @floatFromInt(screenh)};

const aniSpeed: f32 = 4;

var cameraPos = Vec2 {0, 0};
var cameraPrevPos = Vec2 {0, 0};
var cameraAni: ?f32 = null;

var playerPos = Vec2 {0, 0};
// var playerPrevPos = Vec2 {0, 0};
// var playerAni: ?f32 = null; // whenever a blocking animation, this value goes from 0 - 1
var playerAcc = Vec2 {0, 0};
var playerSpd = Vec2 {0, 0};
var playerSpdDecay: f32 = 0.75;

var playerTurn: f32 = 0;
var playerTurnAcc: f32 = 0;
var playerTurnSpd: f32 = 0;
var playerTurnDecay: f32 = 0.75;

const playerSize = Vec2 {0.2, 0.2};
var playerThrust: f32 = 500;
var playerTurnThrust: f32 = 1000;

var playerFireRate: f32 = 10;
var playerPrevFire: f64 = 0;

const objectPos = Vec2 {-0.4, 0.4};



const Bullet = struct {
	spd: Vec2 = @splat(100),
	tex: ?*rl.Texture2D = null,
	pos: Vec2 = .{0, 0},
	turn: f32 = 0,
	dmg: f32 = 0,
	// size: Vec2,
};

const Asteriod = struct {
	spd: Vec2,
	tex: ?*rl.Texture2D = null,
	pos: Vec2 = .{0, 0},

	turn_spd: f32 = 0,
	turn: f32 = 0,
	size: Vec2,
	hp: f32 = 50,

	explode_player: AnimationPlayer,
};

// const DefaultBullet = struct {
	
// };
fn splat(i: f32) Vec2 {
	return @splat(i);
}
fn coordn2srl(v: Vec2) rl.Vector2 {
	return v2rl((v + splat(1.0)) * splat(0.5) * screenSizef + Vec2 {(screenwf - screenhf)/2, 0.0});
}
fn sizen2srl(v: Vec2) rl.Vector2 {
	return v2rl(v * screenSizef * splat(0.5));
}
inline fn v2rl(v: Vec2) rl.Vector2 {
	return .{.x = v[0], .y = v[1]};
}
inline fn v2eq0(v: Vec2) bool {
	return v[0] == 0 and v[1] == 0;
}
inline fn v2lerp(from: Vec2, to: Vec2, t: f32) Vec2 {
	return (to - from) * splat(t) + from;
}
fn v2rot(v: Vec2, rot: f32) Vec2 {
	return Vec2 {@cos(rot), @sin(rot)} * splat(v[0]) + Vec2 {-@sin(rot), @cos(rot)} * splat(v[1]);
}
inline fn v2len(v: Vec2) f32 {
	return @sqrt(@reduce(.Add, v*v));
}

inline fn v2n(v: Vec2) Vec2 {
	return v / splat(v2len(v));
}
inline fn v2dist(a: Vec2, b: Vec2) f32 {
	return v2len(a - b);
}

inline fn DrawRectCentered(pos: Vec2, size: Vec2, c: rl.Color) void {
	rl.DrawRectangleV(coordn2srl(pos - size / splat(2.0)), sizen2srl(size), c);
}
fn DirFromKey() Vec2 {
	return 
	// 		if (rl.IsKeyDown(rl.KEY_LEFT)) 	 .{-1, 0}
	// else 	if (rl.IsKeyDown(rl.KEY_RIGHT))  .{1, 0}
	// else 	
			if (rl.IsKeyDown(rl.KEY_UP))  		.{0, -1}
	else 	if (rl.IsKeyDown(rl.KEY_DOWN))  	.{0, 1}
	else 										.{0, 0};
}
fn TurnFromKey() f32 {
	return 
	// 		if (rl.IsKeyDown(rl.KEY_LEFT)) 	 .{-1, 0}
	// else 	if (rl.IsKeyDown(rl.KEY_RIGHT))  .{1, 0}
	// else 	
			if (rl.IsKeyDown(rl.KEY_RIGHT))  1
	else 	if (rl.IsKeyDown(rl.KEY_LEFT))  -1
	else 									0;
}
var bulletSize = Vec2 {0.05, 0.05};
var bullets: [1024]Bullet = undefined;
var bulletCt: usize = 0;

var asteriods: [10]Asteriod = undefined;
var asteriodsCt: usize = 0;

	
var randGen = std.Random.DefaultPrng.init(0);
fn shootBullet(tex: *const rl.Texture2D) void {
	defer bulletCt = (bulletCt + 1) % bullets.len;
	const b = &bullets[bulletCt];
	b.tex = @constCast(tex);
	b.pos = playerPos;
	b.spd = v2rot(.{0, -1.5}, playerTurn) + playerSpd;
	b.turn = playerTurn;
	b.dmg = 5;
}
fn randf(min: f32, max: f32) f32 {
	const range = max - min;
	return randGen.random().float(f32) * range + min;
}
fn randSign() f32 {
	return if (randGen.random().float(f32) > 0.5) 1 else -1;
}
fn spawnAsteriod(anim: *Animation) void {
	defer asteriodsCt = (asteriodsCt + 1) % asteriods.len;
	const a = &asteriods[asteriodsCt];

	var player = AnimationPlayer {.anim = anim};
	a.tex = @constCast(player.play(0));
	a.pos = .{randSign() * randf(1.1, 1.5), randSign() * randf(1.1, 1.5)};
	a.turn = randGen.random().float(f32);
	const target = Vec2 {randf(-0.75, 0.75), randf(-0.75, 0.75)};
	a.spd = v2n(target - a.pos) * splat(randf(0.1, 0.5));
	a.turn_spd = randf(-0.75, 0.75);
	a.size = splat(randf(0.25, 0.5));
	a.hp = a.size[0] * a.size[0] * 200;
	a.explode_player = player;
	
	
}
const Frames = std.ArrayList(rl.Texture2D);
const Animation = struct {
	frames: Frames,
	img: rl.Image,
	pub fn init(path: [*c]const u8, allocator: std.mem.Allocator) Animation {
		var total_frame_ct: usize = 0;
		var res = Animation {.frames = Frames.init(allocator), .img = rl.LoadImageAnim(path, @ptrCast(&total_frame_ct))};
		for (0..total_frame_ct) |i| {
			const off = @as(usize, @intCast(res.img.width*res.img.height))*4*i;
			const tex = rl.LoadTextureFromImage(res.img);
			const data: [*]u8 = @ptrCast(res.img.data orelse unreachable);
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
const AnimationPlayer = struct {
	spd: f32 = 2,
	curr_frame: usize = 0,
	et: f32 = 0,
	anim: *Animation,
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
};

pub fn main() !void {
	const c_alloc = std.heap.c_allocator;
	rl.InitWindow(screenw, screenh, "My Window Name");
	rl.SetTargetFPS(144);
	rl.SetTraceLogLevel(rl.LOG_ERROR);
	defer rl.CloseWindow();


	var explode_anim = Animation.init("assets/asteriod-explode2.gif", c_alloc);
	defer explode_anim.deinit();
	var thrust_anim = Animation.init("assets/thurst.gif", c_alloc);
	defer thrust_anim.deinit();
	var thrust_player = AnimationPlayer {.anim = &thrust_anim, .spd = 5};


	const fighter_tex = rl.LoadTexture("assets/fighter.png");
	const bullet_tex = rl.LoadTexture("assets/bullet.png");
	const asteroid_tex = rl.LoadTexture("assets/asteriod.png");

	// const asteroid_explode_tex = rl.LoadTexture("assets/asteriod-explode.png");
	defer { 
		rl.UnloadTexture(fighter_tex); 
		rl.UnloadTexture(bullet_tex); 
		rl.UnloadTexture(asteroid_tex);
	}
	const up = Vec2 {0, -1};
	while (!rl.WindowShouldClose()) {
		var aa = std.heap.ArenaAllocator.init(c_alloc);
		defer aa.deinit();
		const t = rl.GetFrameTime();
		const et = rl.GetTime();
		// std.log.debug("t: {}", .{t});
		rl.BeginDrawing();
		{
			if (rl.IsKeyPressed(rl.KEY_R)) {
				playerTurnAcc 	= 0;
				playerTurnSpd 	= 0;
				playerTurn 		= 0;

				playerAcc = .{0, 0};
				playerSpd = .{0, 0};
				playerPos = .{0, 0};
			}

			rl.ClearBackground(BgColor);
			playerTurnAcc 	 = TurnFromKey() * t * playerTurnThrust;
			playerTurnSpd 	+= playerTurnAcc * t;
			playerTurn 		+= playerTurnSpd * t;
			playerTurnSpd 	*= 1 - (1 - playerTurnDecay) * t;

			playerAcc  = v2rot(DirFromKey(), playerTurn) * splat(t * playerThrust);
			playerSpd += playerAcc * splat(t);
			playerPos += playerSpd * splat(t);
			playerSpd *= splat(1 - (1 - playerSpdDecay) * t);


			{
				const pos = coordn2srl(playerPos);
				const tw: f32 = @floatFromInt(fighter_tex.width);
				const th: f32  = @floatFromInt(fighter_tex.height);
				const dest = sizen2srl(playerSize);
				const dw = dest.x;
				const dh = dest.y;
				rl.DrawTexturePro(
					fighter_tex,
					.{.x =0, .y = 0, .width = tw, .height = th}, 
					.{.x = pos.x, .y = pos.y, .width = dh, .height = dw},
							.{.x = dw/2, .y = dh/2},
					playerTurn / rl.PI * 180.0, rl.WHITE);




			}
			{
				const thrust_tex = thrust_player.play(t).*;
				const dir = v2rot(up, playerTurn) * splat(0.6 * playerSize[1]);
				const pos = coordn2srl(playerPos - dir);
				const tw: f32 = @floatFromInt(thrust_tex.width);
				const th: f32  = @floatFromInt(thrust_tex.height);
				const dest = sizen2srl(playerSize * splat(0.25));
				const dw = dest.x;
				const dh = dest.y;
				rl.DrawTexturePro(
					thrust_tex,
					.{.x =0, .y = 0, .width = tw, .height = th}, 
					.{.x = pos.x, .y = pos.y, .width = dh, .height = dw},
							.{.x = dw/2, .y = dh/2},
					playerTurn / rl.PI * 180.0, rl.WHITE);




			}
			if (rl.IsKeyDown(rl.KEY_SPACE) and et - playerPrevFire >= 1/playerFireRate) {
				playerPrevFire = et;
				shootBullet(&bullet_tex);
			}
			if (rl.IsKeyPressed(rl.KEY_A)) {
				spawnAsteriod(&explode_anim);
			}


			outer: for (&bullets) |*b| {
				const tex = b.tex orelse continue;
				b.pos += b.spd * splat(t);
				const pos = coordn2srl(b.pos);
				const tw: f32 = @floatFromInt(tex.width);
				const th: f32  = @floatFromInt(tex.height);
				const dest = sizen2srl(bulletSize);
				const dw = dest.x;
				const dh = dest.y;
				rl.DrawTexturePro(
				tex.*, 
				.{.x =0, .y = 0, .width = tw, .height = th}, 
				.{.x = pos.x, .y = pos.y, .width = dh, .height = dw},
						.{.x = dw/2, .y = dh/2},
				b.turn / rl.PI * 180.0, rl.WHITE);
				rl.DrawCircleLinesV(pos ,dw, rl.RED);
				for (&asteriods) |*a| {
					_ = a.tex orelse continue;
					const dist = v2dist(a.pos, b.pos);
					if (dist < bulletSize[0]/2 + a.size[0]/2) {
						a.hp -= b.dmg;
						b.tex = null;
						continue :outer;
					}
				}
			}
			for (&asteriods) |*a| {
				if (a.tex != null and a.hp <= 0) {
					a.tex = if (a.explode_player.isLast()) null else a.explode_player.play(t);
				}
				const tex = a.tex orelse continue;
				a.pos += a.spd * splat(t);
				a.turn += a.turn_spd * t;
				const pos = coordn2srl(a.pos);
				const tw: f32 = @floatFromInt(tex.width);
				const th: f32  = @floatFromInt(tex.height);
				const dest = sizen2srl(a.size);
				const dw = dest.x;
				const dh = dest.y;
				rl.DrawTexturePro(
				tex.*, 
				.{.x =0, .y = 0, .width = tw, .height = th}, 
				.{.x = pos.x, .y = pos.y, .width = dh, .height = dw},
						.{.x = dw/2, .y = dh/2},
				a.turn / rl.PI * 180.0, rl.WHITE);
				rl.DrawCircleLinesV(pos, dw/2, rl.RED);
			}



			const dir = v2rot(up, playerTurn);
			rl.DrawLineV(coordn2srl(playerPos), coordn2srl(playerPos + dir), rl.RED);
			rl.DrawCircleV(coordn2srl(playerPos), 2, rl.RED);

		}


		rl.EndDrawing();
	}
}