local IFeature = require("ui.material.IFeature")

---@class ui.material.TextureSize : ui.IFeature
local TextureSize = IFeature + {}

---@class ui.material.TextureSize.Config
---@field width number
---@field height number

---@param config ui.material.TextureSize.Config
function TextureSize.validateConfig(config)
	config.width = config.width or 0
	config.height = config.height or 0
end

---@param _ ui.material.TextureSize.Config[]
function TextureSize.getHash(_)
	return "TextureSize"
end

---@param shader_code ui.Shader.Code
function TextureSize.build(_, shader_code)
	shader_code.buffer:addField("vec2", "size")
end

---@param config ui.material.TextureSize.Config
---@param data number[]
function TextureSize.packArrayData(config, data)
	table.insert(data, config.width)
	table.insert(data, config.height)
end

return TextureSize
