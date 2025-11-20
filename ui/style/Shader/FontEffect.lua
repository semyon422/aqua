local Feature = require("ui.style.Shader.Feature")

---@class ui.Feature.FontEffect : ui.ShaderFeature
---@operator call: ui.Feature.FontEffect
local FontEffect = Feature + {}

FontEffect.name = "linear_gradient"
FontEffect.layer = 002.000

FontEffect.uniforms = {
	"float font_outline_width",
	"vec4 font_outline_color",
	"vec4 font_color",
}

FontEffect.functions = [[
	vec4 applyFontEffect(vec4 tex_color) {
		float distance = tex_color.a;
		float edge_width = length(vec2(dFdx(distance), dFdy(distance)));
		float alpha = smoothstep(0.5 - edge_width, 0.5 + edge_width, distance);
	
		float outline_alpha = smoothstep(
			0.5 - style.font_outline_width - edge_width,
			0.5 - style.font_outline_width + edge_width,
			distance
		);

		outline_alpha *= (1.0 - alpha);
	
		vec4 final_color = mix(style.font_outline_color, style.font_color, alpha);
		final_color.a = alpha + outline_alpha * style.font_outline_color.a;
		return final_color;
	}
]]

FontEffect.apply = [[
	tex_color = applyFontEffect(tex_color);
]]

---@param color ui.Color
---@param outline_color ui.Color
---@param outline_width number
function FontEffect:new(color, outline_color, outline_width)
	self.color = color or { 1, 1, 1, 1 }
	self.outline_color = outline_color or { 0, 0, 0, 1 }
	self.outline_width = outline_width or 0
	assert(#self.color == 4, "Color table should have 4 numbers")
	assert(#self.outline_color == 4, "Outline color table should have 4 numbers")
end

---@param data any[]
function FontEffect:addUniforms(data)
	table.insert(data, self.outline_width)
	table.insert(data, self.outline_color[1])
	table.insert(data, self.outline_color[2])
	table.insert(data, self.outline_color[3])
	table.insert(data, self.outline_color[4])
	table.insert(data, self.color[1])
	table.insert(data, self.color[2])
	table.insert(data, self.color[3])
	table.insert(data, self.color[4])
end

return FontEffect
