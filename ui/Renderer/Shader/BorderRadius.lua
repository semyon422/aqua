local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.BorderRadius : ui.ShaderFeature
---@operator call: ui.Feature.BorderRadius
local BorderRadius = Feature + {}

BorderRadius.name = "border_radius"
BorderRadius.layer = 090.000
BorderRadius.uniforms = {
	"vec4 corner_radii"
}

BorderRadius.functions = [[
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

	float applyCorners(vec2 uv) {
		vec2 half_size = style.size * 0.5;
		vec2 p = (uv * style.size) - half_size;
		float d = roundRect(p, half_size, style.corner_radii);
		float edge = fwidth(d) * 0.5;
		float alpha = 1.0 - smoothstep(-edge, edge, d);
		return alpha;
	}
]]

BorderRadius.apply = [[
	tex_color.a = tex_color.a * applyCorners(uv);
]]

---@param corner_radii number[]
function BorderRadius:new(corner_radii)
	self.corner_radii = corner_radii or { 0, 0, 0, 0 }
	assert(#self.corner_radii == 4, "corner_radii table should have 4 numbers")
end

---@param data any[]
function BorderRadius:addUniforms(data)
	table.insert(data, self.corner_radii[1])
	table.insert(data, self.corner_radii[2])
	table.insert(data, self.corner_radii[3])
	table.insert(data, self.corner_radii[4])
end

return BorderRadius
