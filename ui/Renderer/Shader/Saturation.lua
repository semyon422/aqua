local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Saturation : ui.ShaderFeature
---@operator call: ui.Saturation
local Saturation = Feature + {}

Saturation.name = "saturation"

Saturation.uniforms = {
	"float saturation"
}

Saturation.functions = [[
	vec3 applySaturation(vec3 color) {
		float luminance = dot(color, vec3(0.299, 0.587, 0.114));
		return mix(vec3(luminance), color, style.saturation);
	}
]]

Saturation.apply = [[
	tex_color.rgb = applySaturation(tex_color.rgb);
]]

function Saturation:new(value)
	self.saturation = assert(value, "Number expected in the constuctor")
end

---@param data any[]
function Saturation:addUniforms(data)
	table.insert(data, self.saturation)
end

return Saturation
