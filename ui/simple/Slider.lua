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

local thumb_padding = 6

function Slider:load()
	self.value = self.getValue()
	self.thumb_position = self:thumbPositionFromPercent()
	self.thumb_target_position = self.thumb_position
end

function Slider:percentFromValue(v)
	return (v - self.min) / (self.max - self.min)
end

function Slider:thumbPositionFromPercent(p)
	return self.thumb_max_width * p
end

function Slider:updateWorldTransform()
	Drawable.updateWorldTransform(self)
	local w, h = self:getDimensions()
	self.thumb_max_width = w - thumb_padding
	self.thumb_size = h - thumb_padding
end

---@param e ui.DragEvent
function Slider:onDrag(e)
	self:calcTargetPercent(e.x)
end

---@param e ui.MouseClickEvent
function Slider:onMouseClick(e)
	self:calcTargetPercent(e.x)
end

---@param x number
function Slider:calcTargetPercent(screen_mouse_x)
	local x, y = self.world_transform:inverseTransformPoint(screen_mouse_x, 0)
	self.thumb_target_position = self:thumbPositionFromPercent(p)
	local p = math_util.round(p * (self.max - self.min) + self.min, self.step)
	self.setValue(math_util.round(self.value, self.step))
end

function Slider:update(dt)
	local diff = (self.target_percent - self.percent) * math.pow(0.65, dt / 0.016)
	self.percent = self.target_percent - diff
end

function Slider:draw()
	local w, h = self:getDimensions()
	love.graphics.setColor(0.1, 0.1, 0.1, 1)
	ui.rectangle(w, h, h / 2 + 1)

	love.graphics.translate(thumb_padding / 2, thumb_padding / 2)
	love.graphics.setColor(0.9, 0.9, 0.9, 1)

	local thumb_max_width = self.thumb_max_width
	self.thumb_width = math_util.clamp(thumb_max_width * self.percent, 0, thumb_max_width)
	ui.rectangle(self.thumb_width, self.thumb_size, self.thumb_size / 2 + 1)
end

return Slider
