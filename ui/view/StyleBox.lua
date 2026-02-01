local Node = require("ui.view.Node")
local Material = require("ui.material.Material")
local BackgroundColor = require("ui.material.features.BackgroundColor")

---@class view.StyleBox : view.Node
---@operator call: view.StyleBox
---@field material ui.Material
local StyleBox = Node + {}

-- Rounded corners SDF
-- Outline SDF
-- Gradients and solid colors

---@class view.StyleBox.Params
---@field background_color ui.Color

local pixel = love.graphics.newCanvas(1, 1)

---@param params view.StyleBox.Params
function StyleBox:init(params)
	self.material = Material()

	if params.background_color then
		self:addBackgroundColor(params.background_color)
	end
end

---@param background_color ui.Color
function StyleBox:addBackgroundColor(background_color)
	---@type ui.material.BackgroundColor.Config.Solid
	local config = {
		fill = "solid",
		color = background_color
	}

	self.material:set(BackgroundColor, config)
end

function StyleBox:draw()
	if self.material.is_dirty then
		self.material:updateShader()
	end

	local shader, ssbo = self.material.shader, self.material.ssbo
	local box = self.layout_box
	shader:send("material_buffer", ssbo)
	love.graphics.setShader(shader)
	love.graphics.draw(pixel, 0, 0, 0, box.x.size, box.y.size)
end

return StyleBox
