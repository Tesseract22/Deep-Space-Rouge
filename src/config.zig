pub const screenh = 1080;
//pub const screenRatio = 16.0/9.0;
pub const screenRatio = 16.0/9.0;
pub const screenw: comptime_int = @intFromFloat(screenh * screenRatio);

pub const screenhf: f32 = @floatFromInt(screenh);
pub const screenwf: f32 = @floatFromInt(screenw);
pub const aniSpeed: f32 = 4;

pub const round_about_extra_space: f32 = 1.2;

pub const pixelMul: f32 = 2;
pub var debug: bool = false;





