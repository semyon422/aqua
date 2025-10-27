local Feature = require("ui.Renderer.Shader.Feature")

---@class ui.Feature.Size
---@operator call: ui.Feature.Size
local Size = Feature + {}

Size.name = "size"

Size.uniforms = {
	size = "vec2"
}

local size = { 0, 0 }

---@param style ui.Style
---@param shader love.Shader
function Size:passUniforms(style, shader)
	size[1] = style.width
	size[2] = style.height
	style.shader:send("size", size)
end

return Size
