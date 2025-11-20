local Feature = require("ui.style.Shader.Feature")

---@class ui.DropShadow : ui.ShaderFeature
---@operator call: ui.DropShadow
--- Only use inside a Renderer class.
local DropShadow = Feature + {}

DropShadow.name = "drop_shadow"

DropShadow.uniforms = {
	"vec4 shadow_color",
	"float shadow_radius"
}

DropShadow.apply = [[
	vec2 expanded_size = style.size + vec2(style.shadow_radius * 2.0);
	vec2 half_size = style.size * 0.5;
	vec2 p = (uv - 0.5) * expanded_size;
	float dist = roundRect(p, half_size, style.border_radius);
	float shadow = 1.0 - smoothstep(0.0, style.shadow_radius, dist);
	tex_color = vec4(style.shadow_color.rgb, style.shadow_color.a * shadow);
]]

function DropShadow:new(color, radius)
	self.color = assert(color, "Color expected")
	self.radius = assert(radius, "Number expected in the constuctor")
	assert(#self.color == 4, "Color table should have 4 numbers")
end

---@param data any[]
function DropShadow:addUniforms(data)
	table.insert(data, self.color[1])
	table.insert(data, self.color[2])
	table.insert(data, self.color[3])
	table.insert(data, self.color[4])
	table.insert(data, self.radius)
end

return DropShadow
