local Drawable = require("ui.Drawable")
local ui = require("ui")
local math_util = require("math_util")

---@class ui.Simple.Slider.Params
---@field min number
---@field max number
---@field step number
---@field getValue fun(): number
---@field setValue fun(v: number)

---@class ui.Simple.Slider : ui.Drawable, ui.Simple.Slider.Params
---@overload fun(params: ui.Simple.Slider.Params): ui.Simple.Slider
local Slider = Drawable + {}

Slider.ClassName = "Slider"

Slider.height = 24
Slider.handles_mouse_input = true

function Slider:load()
	self.value = self.getValue()
	self.thumb_position = self:thumbPositionFromValue(self.value)
	self.thumb_target_position = self.thumb_position
end

---@param v number
function Slider:thumbPositionFromValue(v)
	local p = (v - self.min) / (self.max - self.min)
	p = math_util.clamp(p, 0, 1)
	return self.width * p
end

---@param x number
function Slider:valueFromThumbPosition(x)
	local p = math_util.clamp(x / self:getWidth(), 0, 1)
	return ((self.max - self.min) * p) + self.min
end

---@param e ui.DragEvent
function Slider:onDrag(e)
	self:calcTargetPercent(e.x, e.y)
end

---@param e ui.MouseClickEvent
function Slider:onMouseClick(e)
	self:calcTargetPercent(e.x, e.y)
end

---@param x number
function Slider:calcTargetPercent(screen_mouse_x, screen_mouse_y)
	local x, _ = self.world_transform:inverseTransformPoint(screen_mouse_x, screen_mouse_y)
	local value = self:valueFromThumbPosition(x)
	self.setValue(math_util.round(value, self.step))
	self.thumb_target_position = self:thumbPositionFromValue(value)
end

function Slider:update(dt)
	local diff = (self.thumb_target_position - self.thumb_position) * math.pow(0.65, dt / 0.016)
	self.thumb_position = self.thumb_target_position - diff
end

function Slider:draw()
	local w, h = self:getDimensions()
	love.graphics.setColor(0.1, 0.1, 0.1, 1)
	ui.rectangle(w, h, h / 2 + 1)

	love.graphics.setColor(0.9, 0.9, 0.9, 1)
	ui.rectangle(self.thumb_position, h, h / 2 + 1)
end

return Slider
