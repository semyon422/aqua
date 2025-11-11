local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.LinearGradient : ui.ShaderFeature
---@operator call: ui.Feature.LinearGradient
local LinearGradient = Feature + {}

LinearGradient.name = "linear_gradient"
LinearGradient.layer = 002.000

LinearGradient.uniforms = {
	"vec4 linear_gradient_color1",
	"vec4 linear_gradient_color2",
	"vec2 linear_gradient_dir"
}

LinearGradient.functions = [[
	vec4 applyLinearGradient(vec2 uv, vec4 tex_color) {
		vec2 centered = uv - 0.5;
		float t = dot(centered, style.linear_gradient_dir) + 0.5;
		
		float dither = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
		dither = (dither - 0.5) * 0.01;
		t = clamp(t + dither, 0.0, 1.0);

		vec4 grad = mix(style.linear_gradient_color1, style.linear_gradient_color2, t);

		float inv_alpha = 1.0 - grad.a;
		vec3 blended_rgb = mix(grad.rgb, tex_color.rgb, inv_alpha);
		float blended_alpha = tex_color.a + grad.a * (1.0 - tex_color.a);

		return vec4(blended_rgb, blended_alpha);
	}
]]

LinearGradient.apply = [[
	tex_color = applyLinearGradient(uv, tex_color);
]]

---@param color1 ui.Color
---@param color2 ui.Color
---@param angle number Radians
function LinearGradient:new(color1, color2, angle)
	self.color1 = color1 or { 1, 1, 1, 1 }
	self.color2 = color2 or { 1, 1, 1, 1 }
	self.angle = angle or 0
	assert(#self.color1 == 4, "Color1 table should have 4 numbers")
	assert(#self.color2 == 4, "Color2 table should have 4 numbers")
end

---@param data any[]
function LinearGradient:addUniforms(data)
	table.insert(data, self.color1[1])
	table.insert(data, self.color1[2])
	table.insert(data, self.color1[3])
	table.insert(data, self.color1[4])
	table.insert(data, self.color2[1])
	table.insert(data, self.color2[2])
	table.insert(data, self.color2[3])
	table.insert(data, self.color2[4])
	table.insert(data, math.cos(self.angle))
	table.insert(data, math.sin(self.angle))
end

return LinearGradient
