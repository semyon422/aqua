local ui = require("ui")
local MouseClickEvent = require("ui.input_events.MouseClickEvent")

---@class ui.Simple.Button.Params
---@field font_name string
---@field font_size number
---@field text string
---@field on_click function

---@class ui.Simple.Button : ui.Drawable, ui.Simple.Button.Params
---@overload fun(params: ui.Simple.Button.Params): ui.Simple.Button
local Button = ui.Drawable + {}

Button.ClassName = "Button"

function Button:load()
	self.label = self:add(ui.Label({
		anchor = ui.Pivot.Center,
		origin = ui.Pivot.Center,
		font_name = self.font_name,
		font_size = self.font_size,
		text = self.text,
	}))

	local w, h = self.label:getDimensions()
	self:setWidth(w + 12)
	self:setHeight(h + 8)
	self.accepts_input = true
end

---@param text string
function Button:replaceText(text)
	self.text = text
	self:clearTree()
	self:load()
end

---@param e ui.MouseClickEvent
function Button:onMouseClick(e)
	self.on_click(self)
end

function Button:draw()
	if self.mouse_over then
		love.graphics.setColor(0.4, 0.4, 0.4)
	else
		love.graphics.setColor(0.2, 0.2, 0.2)
	end

	love.graphics.rectangle("fill", 0, 0, self:getWidth(), self:getHeight())
end

return Button
