---@class ui.ShaderBuilder
local ShaderBuilder = {}

ShaderBuilder.cache = {}
ShaderBuilder.buffer_name = "style_buffer"

local SHADER_TEMPLATES = {
	header = [[
		#pragma language glsl4

		uniform vec2 uv_scale;

		struct Style {
			vec2 size;
			vec4 border_radius;
	]],

	buffer = ([[};
		layout(std430) readonly buffer %s {
			Style _style[];
		};
		Style style = _style[0];
	]]):format(ShaderBuilder.buffer_name),

	functions = [[
		float roundRect(vec2 p, vec2 half_size, vec4 radii) {
			vec2 q = p;
			float r;

			if (p.x < 0.0 && p.y < 0.0) {
				r = radii.x;
			} else if (p.x >= 0.0 && p.y < 0.0) {
				r = radii.y;
			} else if (p.x >= 0.0 && p.y >= 0.0) {
				r = radii.z;
			} else {
				r = radii.w;
			}

			r = min(r, min(half_size.x, half_size.y));

			vec2 d = abs(p) - half_size + vec2(r);
			return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
		}
	]],

	effect_start = [[
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
			vec2 scaled_uv = uv / uv_scale;
			vec4 tex_color = Texel(tex, uv);
	]],
	effect_end = [[return tex_color * color;}]]
}

---@param shader love.Shader
---@return table
local function createBuffer(shader)
	local fmt = shader:getBufferFormat(ShaderBuilder.buffer_name)
	return love.graphics.newBuffer(fmt, #fmt, { shaderstorage = true })
end

---@param features ui.ShaderFeature[]
---@return string
local function generateCacheKey(features)
	local parts = {}
	for i, feature in ipairs(features) do
		parts[i] = feature.name
	end
	return table.concat(parts, "+")
end

---@param features ui.ShaderFeature[]
---@return string
local function buildShaderCode(features)
	local code = { SHADER_TEMPLATES.header }

	for _, feature in ipairs(features) do
		if feature.uniforms then
			for _, uniform in ipairs(feature.uniforms) do
				table.insert(code, uniform .. ";\n")
			end
		end
	end

	table.insert(code, SHADER_TEMPLATES.buffer)
	table.insert(code, SHADER_TEMPLATES.functions)

	for _, feature in ipairs(features) do
		if feature.functions then
			table.insert(code, feature.functions)
		end
	end

	table.insert(code, SHADER_TEMPLATES.effect_start)

	for _, feature in ipairs(features) do
		if feature.apply then
			table.insert(code, feature.apply)
		end
	end

	table.insert(code, SHADER_TEMPLATES.effect_end)

	return table.concat(code)
end

---@param features ui.ShaderFeature[]
---@return love.Shader?
---@return table? buffer
function ShaderBuilder:getShader(features)
	if #features == 0 then
		return
	end

	local key = generateCacheKey(features)

	if self.cache[key] then
		local shader = self.cache[key]
		return shader, createBuffer(shader)
	end

	local code = buildShaderCode(features)
	local shader = love.graphics.newShader(code)
	self.cache[key] = shader

	return shader, createBuffer(shader)
end

return ShaderBuilder
