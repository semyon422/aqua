local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Brightness : ui.ShaderFeature
---@operator call: ui.Brightness
local Brightness = Feature + {}

Brightness.name = "brightness"
Brightness.layer = 080.000

Brightness.uniforms = {
	brightness = "float"
}

Brightness.apply = [[
	tex_color.rgb = tex_color.rgb * brightness;
]]

function Brightness:new(value)
	self.brightness = assert(value, "Number expected in the constuctor")
end

---@param style ui.Style
function Brightness:passUniforms(style)
	style.shader:send("brightness", self.brightness)
end

return Brightness
