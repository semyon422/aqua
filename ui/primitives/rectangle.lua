local shader_code = [[
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
    return vec4(color.rgb, color.a * alpha);
}
]]

local pixel
local shader
local size = { 0, 0 }

---@param width number
---@param height number
---@param radius number?
return function(width, height, radius)
	pixel = pixel or love.graphics.newCanvas(1, 1)
	shader = shader or love.graphics.newShader(shader_code)
	radius = radius or 0
	size[1] = width
	size[2] = height
	shader:send("radius", radius)
	shader:send("size", size)
	love.graphics.setShader(shader)
	love.graphics.push()
	love.graphics.scale(width, height)
	love.graphics.draw(pixel)
	love.graphics.pop()
	love.graphics.setShader()
end
