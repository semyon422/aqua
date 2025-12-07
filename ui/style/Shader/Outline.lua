local Feature = require("ui.style.Shader.Feature")

---@class ui.Feature.Outline : ui.ShaderFeature
---@operator call: ui.Feature.Outline
local Outline = Feature + {}

Outline.name = "border"
Outline.layer = 100.000

Outline.uniforms = {
	"vec4 border_color",
	"float border_width"
}

Outline.functions = [[
	vec4 border(vec2 uv, vec4 tex_color) {
		vec2 half_size = style.size * 0.5;
		vec2 p = (uv * style.size) - half_size;
		float d_outer = roundRect(p, half_size, style.border_radius);
		vec2 inner_half_size = half_size - vec2(style.border_width);
		vec4 inner_radii = max(style.border_radius - vec4(style.border_width), vec4(0.0));
		float d_inner = roundRect(p, inner_half_size, inner_radii);
		float edge = fwidth(d_outer) * 0.5;
		float alpha_outer = 1.0 - smoothstep(-edge, edge, d_outer);
		float alpha_inner = smoothstep(-edge, edge, d_inner);
		float border_mask = alpha_outer * alpha_inner;
		vec4 final_color = mix(tex_color, style.border_color, border_mask);
		final_color.a *= alpha_outer;
		return final_color;
	}
]]

Outline.apply = [[
	tex_color = border(uv, tex_color);
]]

function Outline:new(color, thickness)
	self.color = assert(color, "Color expected")
	self.thickness = assert(thickness, "Thickness expected")
	assert(#self.color == 4, "4 values in color expected")
end

---@param data any[]
function Outline:addUniforms(data)
	table.insert(data, self.color[1])
	table.insert(data, self.color[2])
	table.insert(data, self.color[3])
	table.insert(data, self.color[4])
	table.insert(data, self.thickness)
end

return Outline
