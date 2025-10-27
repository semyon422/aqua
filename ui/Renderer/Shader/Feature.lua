local class = require("class")

---@class ui.ShaderFeature
---@operator call: ui.ShaderFeature
---@field requires ui.ShaderFeature[]?
---@field uniforms {[string]: string}?
---@field functions string?
---@field apply string?
local Feature = class()

Feature.name = "Unnamed"
Feature.layer = math.huge

---@param style ui.Style
function Feature:passUniforms(style) end

return Feature
