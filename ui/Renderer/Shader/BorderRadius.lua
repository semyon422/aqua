local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.BorderRadius : ui.ShaderFeature
---@operator call: ui.Feature.BorderRadius
local BorderRadius = Feature + {}

BorderRadius.name = "border_radius"
BorderRadius.layer = 90000

BorderRadius.requires = {
	require("ui.Renderer.Shader.Size"),
	require("ui.Renderer.Shader.Corners")
}

BorderRadius.functions = [[
	float applyBorderRadius(vec2 uv) {
		vec2 half_size = size * 0.5;
		vec2 p = (uv * size) - half_size;
		float d = roundRect(p, half_size, corner_radii);
		float edge = fwidth(d) * 0.5;
		float alpha = 1.0 - smoothstep(-edge, edge, d);
		return alpha;
	}
]]

BorderRadius.apply = [[
	tex_color = vec4(tex_color.rgb, tex_color.a * applyBorderRadius(uv));
]]

return BorderRadius
