local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.LinearGradient : ui.ShaderFeature
---@operator call: ui.Feature.LinearGradient
local LinearGradient = Feature + {}

LinearGradient.name = "linear_gradient"
LinearGradient.layer = 200

LinearGradient.requires = {
	require("ui.Renderer.Shader.Size")
}

LinearGradient.uniforms = {
	linear_gradient_color1 = "vec4",
	linear_gradient_color2 = "vec4",
	linear_gradient_dir = "vec2"
}

LinearGradient.functions = [[
	vec4 applyLinearGradient(vec2 uv, vec4 tex_color) {
		vec2 centered = (uv / size) - 0.5;
		float t = dot(centered, linear_gradient_dir) + 0.5;
		float dither = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
		dither = (dither - 0.5) / 255.0;
		t = clamp(t + dither, 0.0, 1.0);

		vec4 grad = mix(linear_gradient_color1, linear_gradient_color2, t);

		float inv_alpha = 1.0 - grad.a;
		vec3 blended_rgb = mix(grad.rgb, tex_color.rgb, inv_alpha);
		float blended_alpha = tex_color.a + grad.a * (1.0 - tex_color.a);

		return vec4(blended_rgb, blended_alpha);
	}
]]

LinearGradient.apply = [[
	tex_color = applyLinearGradient(uv * size, tex_color);
]]

local dir = { 0, 0 }

---@param style ui.Style
function LinearGradient:passUniforms(style)
	local s = style.shader
	s:send("linear_gradient_color1", style.linear_gradient[1])
	s:send("linear_gradient_color2", style.linear_gradient[2])
	local a = style.linear_gradient.angle
	dir[1] = math.cos(a)
	dir[2] = math.sin(a)
	s:send("linear_gradient_dir", dir)
end

return LinearGradient
