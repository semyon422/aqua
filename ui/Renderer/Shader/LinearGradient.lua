local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.LinearGradient : ui.ShaderFeature
---@operator call: ui.Feature.LinearGradient
local LinearGradient = Feature + {}

LinearGradient.name = "linear_gradient"
LinearGradient.layer = 200
LinearGradient.uniforms = {
	linear_gradient_color1 = "vec4",
	linear_gradient_color2 = "vec4",
	linear_gradient_dir = "vec2"
}

LinearGradient.functions = [[
	vec4 applyLinearGradient(vec2 uv) {
		vec2 centered = uv - 0.5;
		float t = dot(centered, linear_gradient_dir) + 0.5;
		t = clamp(t, 0.0, 1.0);
		return mix(linear_gradient_color1, linear_gradient_color2, t);
	}
]]

LinearGradient.apply = [[
	tex_color = applyLinearGradient(uv);
]]

local dir = { 0, 0 }

---@param style ui.Style
---@param shader love.Shader
function LinearGradient:passUniforms(style, shader)
	shader:send("linear_gradient_color1", style.linear_gradient[1])
	shader:send("linear_gradient_color2", style.linear_gradient[2])
	local a = style.linear_gradient.angle
	dir[1] = math.cos(a)
	dir[2] = math.sin(a)
	shader:send("linear_gradient_dir", dir)
end

return LinearGradient
