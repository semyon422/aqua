local class = require("class")

---@class ui.Style
---@operator call: ui.Style
---@field width number?
---@field height number?
---@field border_radius [ number, number, number, number ]
---@field border_width number?
---@field border_color ui.Color?
---@field linear_gradient { angle: number, [1]: ui.Color, [2]: ui.Color }?
---@field blur number?
---@field brightness number?
---@field shadows { offset_x: number, offset_y: number, blur_radius: number }[]?
---@field is_backdrop boolean?
---@field backdrop_blur fun(node: ui.Node)?
---@field mask (boolean | fun(node: ui.Node))?
---@field is_canvas boolean?
---@field blend_mode string?
---@field background_color ui.Color?
---@field color ui.Color?
---@field alpha number?
---@field shader love.Shader?
---@field features ui.ShaderFeature[]
local Style = class()

function Style:new(styles)
	self.features = {}

	for k, v in pairs(styles) do
		self[k] = v
	end
end

function Style:set(field_name, value)
	-- Invalidating the shader
	if self[field_name] and value == nil then
		self.shader = nil
	elseif not self[field_name] and value then
		self.shader = nil
	end

	self[field_name] = value
end

function Style:passUniforms()
	for _, feature in ipairs(self.features) do
		feature:passUniforms(self)
	end
end

return Style
