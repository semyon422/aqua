local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.Outline : ui.ShaderFeature
---@operator call: ui.Feature.Outline
local Outline = Feature + {}

Outline.name = "border"
Outline.layer = 100.000

Outline.requires = {
	require("ui.Renderer.Shader.Size"),
	require("ui.Renderer.Shader.Corners")
}

Outline.uniforms = {
	border_color = "vec4",
	border_width = "float"
}

Outline.functions = [[
	vec4 border(vec2 uv, vec4 tex_color) {
		vec2 half_size = size * 0.5;
		vec2 p = (uv * size) - half_size;
		float d_outer = roundRect(p, half_size, corner_radii);
		vec2 inner_half_size = half_size - vec2(border_width);
		vec4 inner_radii = max(corner_radii - vec4(border_width), vec4(0.0));
		float d_inner = roundRect(p, inner_half_size, inner_radii);
		float edge = fwidth(d_outer) * 0.5;
		float alpha_outer = 1.0 - smoothstep(-edge, edge, d_outer);
		float alpha_inner = smoothstep(-edge, edge, d_inner);
		float border_mask = alpha_outer * alpha_inner;
		vec4 final_color = mix(tex_color, border_color, border_mask);
		final_color.a *= alpha_outer;
		return final_color;
	}
]]

Outline.apply = [[
	tex_color = border(uv, tex_color);
]]

---@param style ui.Style
function Outline:passUniforms(style)
	style.shader:send("border_color", style.border_color)
	style.shader:send("border_width", style.border_width)
end

return Outline
