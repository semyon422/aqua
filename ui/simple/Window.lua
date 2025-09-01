local Drawable = require("ui.Drawable")
local Stencil = require("ui.Stencil")
local Rectangle = require("ui.Rectangle")
local WindowTopBar = require("ui.simple.WindowTopBar")

---@class ui.Simple.Window : ui.Drawable
---@operator call: ui.Simple.Window
local Window = Drawable + {}

function Window:load()
	local top_bar = self:add(WindowTopBar({
		width = self:getWidth(),
		height = 30,
	}))
	self:add(Rectangle({
		y = top_bar:getHeight(),
		width = self:getWidth(),
		height = self:getHeight() - top_bar:getHeight(),
		color = { 1, 0, 1, 0.2 }
	}))
	self.container = self:add(Stencil({
		y = top_bar:getHeight(),
		width = self:getWidth(),
		height = self:getHeight() - top_bar:getHeight(),
		z = 1,
	}))
end

return Window
