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
const screenSizef = Vec2 {screenhf, screenhf};

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
var playerMaxSpd  : f32 = 1;

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

fn roundAbout(pos: Vec2) Vec2 {
	const screen_rang = Vec2 {2 * screenwf/screenhf,2};
	const half = screen_rang / splat(2);
	return @mod(pos + half, screen_rang) - half;
	
}

// const DefaultBullet = struct {
	
// };
fn splat(i: f32) Vec2 {
	return @splat(i);
}
fn coordn2srl(v: Vec2) rl.Vector2 {
	return v2rl((v + splat(1.0)) * splat(0.5) * screenSizef + Vec2 {(screenwf - screenhf)/2, 0.0});
}
fn srl2coord(v: rl.Vector2) Vec2 {
	return (rl2v2(v) -  Vec2 {(screenwf - screenhf)/2, 0.0}) * splat(2) / screenSizef - splat(1.0);
}
fn sizen2srl(v: Vec2) rl.Vector2 {
	return v2rl(v * screenSizef * splat(0.5));
}
inline fn v2rl(v: Vec2) rl.Vector2 {
	return .{.x = v[0], .y = v[1]};
}
inline fn rl2v2(rlv: rl.Vector2) Vec2 {
	return .{rlv.x, rlv.y};
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
const up = Vec2 {0, -1};

const pixelMul: f32 = 2.5;

fn shootBullet(tex: *const rl.Texture2D) void {
	defer bulletCt = (bulletCt + 1) % bullets.len;
	const b = &bullets[bulletCt];
	b.tex = @constCast(tex);
	const dir = v2rot(up, playerTurn);
	b.pos = playerPos + dir * splat(playerSize[1]/2);
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

fn diffClock(from: f32, to: f32) f32 {
	const p = 2*rl.PI; // period
	var clock: 		f32 = undefined;
	var counter: 	f32 = undefined;
	if (to > from) {
		clock = to - from;
		counter = from - to + p;
	} else {
		clock = to - from + p;
		counter = from - to;
	}
	return if (clock < counter) clock else -counter; 

}
const Mover = struct {
	spd: Vec2 = .{0, 0},
	pos: Vec2 = .{0, 0},
	acc_rate: f32 = 0.8,
	// acc		: f32 = 0,
	max_spd:  f32 = 0.8,

	turn_spd: f32 = 0,
	turn: f32 = 0,
	turn_acc_rate: f32 = 1,
	// turn_acc: f32 = 0,
	max_turn_spd:  f32 = 5,

	// pub const turn_limit	: f32 = 5 / 180 * rl.PI;


	pub fn turnToPos(m: *Mover, pos: Vec2, dt: f32) void {
		const target_dir = pos - m.pos;
		const target_dir_angle = 
		@mod(std.math.acos(v2dot(up, target_dir) / v2len(target_dir)) * std.math.sign(v2cross(up, target_dir)), 2 * rl.PI);
		return m.turnToDir(target_dir_angle, dt);
	}
	pub fn turnToDir(m: *Mover, dir: f32, dt: f32) void {
		// v*t + 2*a*t*t
		// std.log.debug("dir: {}", .{@as(isize, @intFromFloat(rad2deg(dir)))});
		
		const turn_diff = diffClock(m.turn, dir);
		const turn_dir = std.math.sign(turn_diff);
		// std.log.debug("turn diff: {}, limit {}", .{turn_diff, turn_limit});


		m.turn_spd = m.max_turn_spd * turn_dir;
		const expected = @mod(m.turn_spd * dt + m.turn, 2*rl.PI);
		const expected_diff = diffClock(expected, dir);
		if (expected_diff * turn_dir <= 0) {
			m.turn = dir;
			m.turn_spd = 0;
		} 
	}
	pub fn foward(m: *Mover, dt: f32) void {
		m.spd += v2rot(up, m.turn) * splat(dt * m.acc_rate);
		const l = v2len(m.spd);
		m.spd = m.spd * splat(@min(m.max_spd, l) / l);
	}
	pub fn move(m: *Mover, dt: f32) void {
		m.turn += m.turn_spd * dt;
		m.turn = @mod(m.turn, 2*rl.PI);
		m.pos += m.spd * splat(dt);
	}
	// pub fn turn(self: *Move)


};
const Enemy = struct {
	tex: ?*rl.Texture2D = null,
	size: Vec2 = .{0.15, 0.15},
	warmhole_player: AnimationPlayer = undefined,
	hp: f32 = 0,
	mover: Mover = .{},


	ai_turn_rate: f32 = 5,


	// pub fn turnTo(self: *Enemy, dt: f32) void {

	// 	std.log.debug("turnto", .{});
	// 	const m = &self.mover;
	// 	const player_dir = playerPos - m.pos;
	// 	const player_dir_angle = std.math.acos(v2dot(up, player_dir) / v2len(player_dir)) ;
	// 	{
	// 		var buf:[64:0]u8 = undefined;
	// 		@memset(&buf, 0);
	// 	 	_ = std.fmt.bufPrint(&buf, "{} {}", .{@as(isize, @intFromFloat(player_dir_angle * 180 / rl.PI)), @as(isize, @intFromFloat(playerTurn * 180 / rl.PI))}) catch unreachable;
	// 		rl.DrawText(&buf, 10, 10, 15, rl.RED);
	// 	}
	// 	const turn_diff = player_dir_angle - m.turn;
	// 	if (turn_diff < 5.0 / 180.0 * rl.PI) return;
	// 	const turn_dir: f32  = std.math.sign(turn_diff);
	// 	m.turn += turn_dir * self.ai_turn_rate * dt;
	// }
	
};
var enemies: [128]Enemy = [_]Enemy {Enemy {}} ** 128;
var enemiesCt: usize = 0;
fn spawnEnemy(warmhole_anim: *Animation, enemy_tex: *const rl.Texture2D) void {
	defer enemiesCt += 1;
	const player = AnimationPlayer {.anim = warmhole_anim, .spd = 10};
	const e = &enemies[enemiesCt];
	e.tex = @constCast(enemy_tex);
	e.warmhole_player = player;
	e.hp = 10;
	e.mover.pos = .{randf(-0.8, 0.8), randf(-0.8, 0.8)};
	std.log.debug("pos: {any}", .{e.mover.pos});

	
	

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
	pub fn last(self: AnimationPlayer) usize {
		return self.anim.frames.items.lenm;
	}
};


pub inline fn DrawTexture(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32) void {
	DrawTextureTint(tex, origin, size, rot, rl.WHITE);
	
}

pub fn DrawTextureTint(tex: rl.Texture2D, origin: Vec2, size: ?Vec2, rot: f32, tint: rl.Color) void {
	const pos = coordn2srl(origin);
	const tw: f32 = @floatFromInt(tex.width);
	const th: f32  = @floatFromInt(tex.height);
	var dw: f32 = 0;
	var dh: f32 = 0;
	if (size) |s| {
		const dest = sizen2srl(s);
		dw = dest.x;
		dh = dest.y;
	} else {
		dw = @as(f32, @floatFromInt(tex.width)) 	* pixelMul;
		dh = @as(f32, @floatFromInt(tex.height)) 	* pixelMul;
	}

	rl.DrawTexturePro(
				tex, 
				.{.x = 0, .y = 0, .width = tw, .height = th}, 
				.{.x = pos.x, .y = pos.y, .width = dh, .height = dw},
						.{.x = dw/2, .y = dh/2},
				rot / rl.PI * 180.0, tint);
	rl.DrawCircleLinesV(pos, @max(dw, dh)/2, rl.RED); // debug
	
}

// asteroids => everything
// player => enemies, enemies bullets
// player bulletes => enemies, enemies bulletes

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
	var thrust_player = AnimationPlayer {.anim = &thrust_anim, .spd = 2};
	var warmhole_anim = Animation.init("assets/wormhole.gif", c_alloc);
	defer warmhole_anim.deinit();
	// var warmhole_player = AnimationPlayer {.anim = &warmhole_anim, .spd = 2};
	// _ = warmhole_player; // autofix


	const fighter_tex = rl.LoadTexture("assets/fighter2.png");
	const bullet_tex = rl.LoadTexture("assets/bullet.png");
	const asteroid_tex = rl.LoadTexture("assets/asteriod.png");
	const enemy_tex = rl.LoadTexture("assets/enemy-1.png");

	// const asteroid_explode_tex = rl.LoadTexture("assets/asteriod-explode.png");



	defer { 
		rl.UnloadTexture(fighter_tex); 
		rl.UnloadTexture(bullet_tex); 
		rl.UnloadTexture(asteroid_tex);
	}
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
			playerTurn		 = @mod(playerTurn, 2 * rl.PI);
			playerTurnSpd 	*= 1 - (1 - playerTurnDecay) * t;

			const move_dir = DirFromKey();
			playerAcc  = v2rot(move_dir, playerTurn) * splat(t * playerThrust);
			playerSpd += playerAcc * splat(t);
			// playerSpd += 
			playerPos += playerSpd * splat(t);
			playerPos  = roundAbout(playerPos);
			playerSpd *= splat(1 - (1 - playerSpdDecay) * t);


			DrawTexture(fighter_tex, playerPos, null, playerTurn);
			if (!v2eq0(move_dir)) {
				DrawTexture(thrust_player.play(t).*, playerPos - v2rot(up, playerTurn) * splat(0.6 * playerSize[1]), playerSize * splat(0.25), playerTurn);
			}
			if (rl.IsKeyDown(rl.KEY_SPACE) and et - playerPrevFire >= 1/playerFireRate) {
				playerPrevFire = et;
				shootBullet(&bullet_tex);
			}
			if (rl.IsKeyPressed(rl.KEY_A)) {
				spawnAsteriod(&explode_anim);
			}
			if (rl.IsKeyPressed(rl.KEY_S)) {
				spawnEnemy(&warmhole_anim, &enemy_tex);
			}
			if (rl.IsKeyPressed(rl.KEY_LEFT_SHIFT)) {
				std.log.debug("teleport", .{});
				const mouse_pos = rl.GetMousePosition();
				playerTurnAcc 	= 0;
				playerTurnSpd 	= 0;
				playerTurn 		= 0;

				playerAcc = .{0, 0};
				playerSpd = .{0, 0};
				playerPos = srl2coord(mouse_pos);
				std.log.debug("mouse: {} {any}", .{mouse_pos, playerPos});

			}


			outer: for (&bullets) |*b| {
				const tex = b.tex orelse continue;
				b.pos += b.spd * splat(t);
				DrawTexture(tex.*, b.pos, null, b.turn);
				for (&asteriods) |*a| {
					_ = a.tex orelse continue;
					const dist = v2dist(a.pos, b.pos);
					if (dist < bulletSize[0]/2 + a.size[0]/2) {
						a.hp -= b.dmg;
						b.tex = null;
						continue :outer;
					}
				}
				for (&enemies) |*e| {
					_ = e.tex orelse continue;
					const m = &e.mover;
					const dist = v2dist(m.pos, b.pos);
					if (dist < bulletSize[0]/2 + e.size[0]/2) {
						e.hp -= b.dmg;
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
				DrawTexture(tex.*, a.pos, a.size, a.turn);
			}
			for (&enemies) |*e| {
				const tex = e.tex orelse continue;
				const m = &e.mover;
				const hole_rot = m.turn + rl.PI / 2;
				const hole_pos = m.pos + v2rot(.{0.15, 0}, hole_rot);
				if (!e.warmhole_player.isLast()) {
					const worm_tex = e.warmhole_player.play(t);
					DrawTexture(worm_tex.*, hole_pos, null, hole_rot);
					if (e.warmhole_player.curr_frame >= 16 ) {
						const ratio = @as(f32,@floatFromInt(e.warmhole_player.curr_frame)) / @as(f32,@floatFromInt(e.warmhole_player.anim.frames.items.len));
						const c: u8 = @intFromFloat(ratio * ratio * 255);
						const tint = rl.Color {.r = c, .g = c, .b = c, .a = c};
						const lerp_pos= v2lerp(hole_pos, m.pos, @log2(ratio + 1));
						DrawTextureTint(tex.*, lerp_pos, null, m.turn, tint);

					}
				} else {
					m.turnToPos(playerPos, t);
					m.foward(t);
					m.move(t);
					DrawTexture(tex.*, m.pos, null, m.turn);
				}

			}



			const dir = v2rot(up, playerTurn);
			rl.DrawLineV(coordn2srl(playerPos), coordn2srl(playerPos + dir), rl.RED);
			rl.DrawCircleV(coordn2srl(playerPos), 2, rl.RED);

		}


		rl.EndDrawing();
	}
}