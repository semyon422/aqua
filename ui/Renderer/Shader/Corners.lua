local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.Corners : ui.ShaderFeature
---@operator call: ui.Feature.Corners
local Corners = Feature + {}

Corners.name = "Corners"
Corners.layer = -math.huge
Corners.uniforms = {
	corner_radii = "vec4"
}

Corners.functions = [[
	float roundRect(vec2 p, vec2 half_size, vec4 radii) {
		vec2 q = p;
		float r;

		if (p.x < 0.0 && p.y < 0.0) {
			r = radii.x;
		} else if (p.x >= 0.0 && p.y < 0.0) {
			r = radii.y;
		} else if (p.x >= 0.0 && p.y >= 0.0) {
			r = radii.z;
		} else {
			r = radii.w;
		}

		r = min(r, min(half_size.x, half_size.y));

		vec2 d = abs(p) - half_size + vec2(r);
		return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
	}
]]

---@param style ui.Style
---@param shader love.Shader
function Corners:passUniforms(style, shader)
	shader:send("corner_radii", style.border_radius)
end

return Corners
