local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Brightness : ui.ShaderFeature
---@operator call: ui.Brightness
local Brightness = Feature + {}

Brightness.name = "brightness"
Brightness.layer = 80000

Brightness.uniforms = {
	brightness = "float"
}

Brightness.functions = [[
	vec4 applyBrightness(vec4 color) {
		color.rgb *= brightness;
		return color;
	}
]]

Brightness.apply = [[
	tex_color = applyBrightness(tex_color);
]]

---@param style ui.Style
function Brightness:passUniforms(style)
	style.shader:send("brightness", style.brightness)
end

return Brightness
