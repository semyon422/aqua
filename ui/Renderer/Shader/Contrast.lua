local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Contrast : ui.ShaderFeature
---@operator call: ui.Contrast
local Contrast = Feature + {}

Contrast.name = "contrast"

Contrast.uniforms = {
	"float contrast"
}

Contrast.apply = [[
	tex_color.rgb = clamp(style.contrast * (tex_color.rgb - 0.5) + 0.5, 0.0, 1.0);
]]

function Contrast:new(value)
	self.contrast = assert(value, "Number expected in the constuctor")
end

---@param data any[]
function Contrast:addUniforms(data)
	table.insert(data, self.contrast)
end

return Contrast
