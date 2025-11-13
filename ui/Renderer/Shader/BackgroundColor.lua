local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.BackgroundColor : ui.ShaderFeature
---@operator call: ui.BackgroundColor
local BackgroundColor = Feature + {}

BackgroundColor.name = "background_color"
BackgroundColor.layer = 001.000

BackgroundColor.uniforms = {
	"vec4 background_color"
}

BackgroundColor.functions = [[
	vec4 applyBackgroundColor(vec4 tex_color) {
		float inv_alpha = 1.0 - tex_color.a;
		vec3 blended_rgb = mix(style.background_color.rgb, tex_color.rgb, tex_color.a);
		float blended_alpha = tex_color.a + style.background_color.a * inv_alpha;
		return vec4(blended_rgb, blended_alpha);
	}
]]

BackgroundColor.apply = [[
	tex_color = applyBackgroundColor(tex_color);
]]

---@param color ui.Color
function BackgroundColor:new(color)
	self.color = color or { 1, 1, 1, 1 }
	assert(#self.color == 4, "Color table should have 4 numbers")
end

---@param data any[]
function BackgroundColor:addUniforms(data)
	table.insert(data, self.color[1])
	table.insert(data, self.color[2])
	table.insert(data, self.color[3])
	table.insert(data, self.color[4])
end

return BackgroundColor
