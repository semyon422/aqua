local IFeature   = require("ui.material.IFeature")
local Function   = require("ui.material.shader.Function")

---@class ui.material.Corners
local Corners    = IFeature + {}

---@alias ui.material.Corners.Shape "round" | "bevel" | "squircle"

---@class ui.material.Corners.Config
---@field top_left_shape ui.material.Corners.Shape?
---@field top_right_shape ui.material.Corners.Shape?
---@field bottom_left_shape ui.material.Corners.Shape?
---@field bottom_right_shape ui.material.Corners.Shape?
---@field top_left_radius number
---@field top_right_radius number
---@field bottom_left_radius number
---@field bottom_right_radius number

local round_rect = Function("float", "roundRect")
round_rect:addArgument("vec2", "p")
round_rect:addArgument("vec2", "half_size")
round_rect:addArgument("float", "radii")
round_rect:addLine([[
vec2 q = p;
float r = min(radii, min(half_size.x, half_size.y));
vec2 d = abs(p) - half_size + vec2(r);
return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
]])

local squircle_rect = Function("float", "squircleRect")
squircle_rect:addArgument("vec2", "p")
squircle_rect:addArgument("vec2", "half_size")
squircle_rect:addArgument("float", "radii")
squircle_rect:addLine([[
vec2 q = p;
float r = min(radii, min(half_size.x, half_size.y));
vec2 d = abs(p) - half_size + vec2(r);
vec2 d_max = max(d, 0.0);
vec2 d2 = d_max * d_max;
float dist_sq = pow(d2.x * d2.x + d2.y * d2.y, 0.25);
return dist_sq + min(max(d.x, d.y), 0.0) - r;
]])

local bevel_rect = Function("float", "bevelRect")
bevel_rect:addArgument("vec2", "p")
bevel_rect:addArgument("vec2", "half_size")
bevel_rect:addArgument("float", "radii")
bevel_rect:addLine([[
float r = min(radii, min(half_size.x, half_size.y));
vec2 d = abs(p) - half_size;
float dist_box = max(d.x, d.y);
vec2 p_abs = abs(p);
float dist_cut = (p_abs.x + p_abs.y - (half_size.x + half_size.y - r)) * 0.70710678;
return max(dist_box, dist_cut);
]])

local idk = {
	round = "\treturn roundRect(p, half_size, radii);",
	bevel = "\treturn bevelRect(p, half_size, radii);",
	squircle = "\treturn squircleRect(p, half_size, radii);"
}

---@param config ui.material.Corners.Config
function Corners.validateConfig(config)
	config.top_left_radius = config.top_left_radius or 0
	config.top_right_radius = config.top_right_radius or 0
	config.bottom_right_radius = config.bottom_right_radius or 0
	config.bottom_left_radius = config.bottom_left_radius or 0
	config.top_left_shape = config.top_left_shape or "round"
	config.top_right_shape = config.top_right_shape or "round"
	config.bottom_right_shape = config.bottom_right_shape or "round"
	config.bottom_left_shape = config.bottom_left_shape or "round"
end

---@param configs ui.material.Corners.Config[]
function Corners.getHash(configs)
	local config = configs[1]
	return ("Corners[%s+%s+%s+%s]"):format(
		config.top_left_shape,
		config.top_right_shape,
		config.bottom_right_shape,
		config.bottom_left_shape
	)
end

---@param configs ui.material.Corners.Config[]
---@param shader_code ui.Shader.Code
function Corners.build(configs, shader_code)
	local config = configs[1]

	shader_code.buffer:addField("vec4", "corner_radii")

	local fn = Function("float", "getCornerAlpha")
	fn:addArgument("vec2", "uv")

	fn:addLine("vec2 half_size = material.size * 0.5;")
	fn:addLine("vec2 p = (uv * material.size) - half_size;")

	fn:addLine("if (p.x < 0.0 && p.y < 0.0) {")
	fn:addLine("\tfloat radii = material.corner_radii.x;")
	fn:addLine(idk[config.top_left_shape])
	fn:addLine("} else if (p.x >= 0.0 && p.y < 0.0) {")
	fn:addLine("\tfloat radii = material.corner_radii.y;")
	fn:addLine(idk[config.top_right_shape])
	fn:addLine("else if (p.x >= 0.0 && p.y >= 0.0) {")
	fn:addLine("\tfloat radii = material.corner_radii.z;")
	fn:addLine(idk[config.bottom_right_shape])
	fn:addLine("} else {")
	fn:addLine("\tfloat radii = material.corner_radii.w;")
	fn:addLine(idk[config.bottom_left_shape])
	fn:addLine("}")

	shader_code.functions["getCornerAlpha"] = fn
end

---@param config ui.material.Corners.Config
---@param data number[]
function Corners.packArrayData(config, data)
	table.insert(data, config.top_left_radius)
	table.insert(data, config.top_right_radius)
	table.insert(data, config.bottom_right_radius)
	table.insert(data, config.bottom_left_radius)
end

return Corners
