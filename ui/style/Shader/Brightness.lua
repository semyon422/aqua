local Feature = require("ui.style.Shader.Feature")

---@class ui.Brightness : ui.ShaderFeature
---@operator call: ui.Brightness
local Brightness = Feature + {}

Brightness.name = "brightness"

Brightness.uniforms = {
	"float brightness"
}

Brightness.apply = [[
	tex_color.rgb = tex_color.rgb * style.brightness;
]]

function Brightness:new(value)
	self.brightness = assert(value, "Number expected in the constuctor")
end

---@param data any[]
function Brightness:addUniforms(data)
	table.insert(data, self.brightness)
end

return Brightness
