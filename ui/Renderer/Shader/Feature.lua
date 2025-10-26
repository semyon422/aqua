local class = require("class")

---@class ui.ShaderFeature
---@operator call: ui.ShaderFeature
---@field requires ui.ShaderFeature[]?
---@field uniforms {[string]: boolean}?
---@field functions string?
---@field apply string?
local Feature = class()

Feature.name = "Unnamed"
Feature.layer = math.huge

---@param style ui.Style
---@param shader love.Shader
function Feature:passUniforms(style, shader) end

return Feature
