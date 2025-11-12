local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.BorderRadius : ui.ShaderFeature
---@operator call: ui.Feature.BorderRadius
local BorderRadius = Feature + {}

BorderRadius.name = "border_radius"
BorderRadius.layer = 090.000

BorderRadius.functions = [[
	float applyCorners(vec2 uv) {
		vec2 half_size = style.size * 0.5;
		vec2 p = (uv * style.size) - half_size;
		float d = roundRect(p, half_size, style.border_radius);
		float edge = fwidth(d) * 0.5;
		float alpha = 1.0 - smoothstep(-edge, edge, d);
		return alpha;
	}
]]

BorderRadius.apply = [[
	tex_color.a = tex_color.a * applyCorners(scaled_uv);
]]

return BorderRadius
