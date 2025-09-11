local fill_shader_code = [[
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
    float alpha = 1.0 - smoothstep(-1.0, 1.0, d);
    return vec4(color.rgb, color.a * alpha);
}
]]

local border_shader_code = [[
extern vec2 size;
extern float radius;
extern float border;

float sdRoundRect(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + vec2(r);
    return length(max(q, 0.0)) - r;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 half_size = size * 0.5;
    vec2 p = (uv * size) - half_size;
    float d_outer = sdRoundRect(p, half_size, radius);
    float d_inner = sdRoundRect(p, half_size - vec2(border), max(radius - border, 0.0));
    float outer_mask = 1.0 - smoothstep(-1.0, 1.0, d_outer);
    float inner_mask = 1.0 - smoothstep(0, 1.0, -d_inner);
    float alpha = outer_mask * inner_mask;
    return vec4(color.rgb, color.a * alpha);
}
]]

local pixel
local fill_shader
local border_shader
local size = { 0, 0 }

---@param width number
---@param height number
---@param radius number?
---@param border number?
return function(width, height, radius, border)
	if not fill_shader then
		fill_shader = love.graphics.newShader(fill_shader_code)
		border_shader = love.graphics.newShader(border_shader_code)
	end

	pixel = pixel or love.graphics.newCanvas(1, 1)

	local shader ---@type love.Shader

	if border then
		shader = border_shader
		shader:send("border", border)
	else
		shader = fill_shader
	end

	width = width + 1 -- compensating for skill issue
	height = height + 1
	size[1] = width
	size[2] = height
	shader:send("radius", radius or 0)
	shader:send("size", size)

	love.graphics.setShader(shader)
	love.graphics.push()
	love.graphics.scale(width, height)
	love.graphics.draw(pixel)
	love.graphics.pop()
	love.graphics.setShader()
end
