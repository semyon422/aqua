local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.BackgroundColor : ui.ShaderFeature
---@operator call: ui.BackgroundColor
local BackgroundColor = Feature + {}

BackgroundColor.name = "background_color"
BackgroundColor.layer = 0

BackgroundColor.uniforms = {
	background_color = "vec4"
}

BackgroundColor.functions = [[
	vec4 applyBackgroundColor(vec4 tex_color) {
		float inv_alpha = 1.0 - tex_color.a;
		vec3 blended_rgb = mix(background_color.rgb, tex_color.rgb, tex_color.a);
		float blended_alpha = tex_color.a + background_color.a * inv_alpha;
		return vec4(blended_rgb, blended_alpha);
	}
]]

BackgroundColor.apply = [[
	tex_color = applyBackgroundColor(tex_color);
]]

---@param style ui.Style
function BackgroundColor:passUniforms(style)
	style.shader:send("background_color", style.background_color)
end

return BackgroundColor
