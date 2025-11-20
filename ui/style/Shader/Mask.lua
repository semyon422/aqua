local Feature = require("ui.style.Shader.Feature")

---@class ui.Features.Mask : ui.ShaderFeature
---@operator call: ui.Features.Mask
local Mask = Feature + {}

Mask.name = "mask"
Mask.layer = -001.000

Mask.uniforms = {
	mask = "Image"
}

Mask.apply = [[
	vec4 mask_tex_color = Texel(mask, uv);
	color = color * mask_tex_color.r;
]]

---@param mask love.Image
function Mask:new(mask)
	self.mask = mask
	assert(self.mask, "Mask is required")
end

---@param style ui.Style
function Mask:passUniforms(style)
	style.shader:send("mask", self.mask)
end

return Mask
