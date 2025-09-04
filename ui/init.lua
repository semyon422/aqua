local Drawable = require("ui.Drawable")

local sound_play_time = {}

---@param sound audio.Source
---@param limit number?
local function playSound(sound, limit)
	if not sound then
		print("no sound")
		return
	end

	limit = limit or 0.05

	local prev_time = sound_play_time[sound] or 0
	local current_time = love.timer.getTime()

	if current_time > prev_time + limit then
		sound:stop()
		sound_play_time[sound] = current_time
	end

	sound:play()
end

local rectangle_shader_code = [[
extern vec2 size;
extern float radius;

float sdRoundRect(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + vec2(r);
    return length(max(q, 0.0)) - r;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 half_size = size * 0.5;
	vec2 p = (uv * size) - half_size;
    float d = sdRoundRect(p, half_size, radius);
    float alpha = 1.0 - smoothstep(0.0, 1.0, d);
    return vec4(color.rgb, color.a * alpha) * color;
}
]]

local pixel

local rectangle_shader
local rectangle_wh = { 0, 0 }
local function rectangle(width, height, radius)
	rectangle_wh[1] = width
	rectangle_wh[2] = height
	rectangle_shader:send("size", rectangle_wh)
	rectangle_shader:send("radius", radius)
	love.graphics.setShader(rectangle_shader)
	love.graphics.push()
	love.graphics.scale(width, height)
	love.graphics.draw(pixel)
	love.graphics.pop()
	love.graphics.setShader()
end

local function init()
	pixel = love.graphics.newCanvas(1, 1)
	rectangle_shader = love.graphics.newShader(rectangle_shader_code)
end

return {
	init = init,
	Drawable = Drawable,
	Padding = require("ui.Padding"),
	VBox = require("ui.VBox"),
	HBox = require("ui.HBox"),
	Stencil = require("ui.Stencil"),
	Image = require("ui.Image"),
	Label = require("ui.Label"),
	Rectangle = require("ui.Rectangle"),
	Pivot = Drawable.Pivot,
	SizeMode = Drawable.SizeMode,
	playSound = playSound,
	rectangle = rectangle
}
