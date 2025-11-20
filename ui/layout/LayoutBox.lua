local class = require("class")
local Pivot = require("ui.layout.Pivot")

---@class ui.LayoutBox
---@operator call: ui.LayoutBox
---@field x number
---@field y number
---@field width number
---@field height number
---@field width_mode ui.SizeMode
---@field height_mode ui.SizeMode
---@field padding_left number
---@field padding_right number
---@field padding_top number
---@field padding_bottom number
---@field child_gap number
---@field arrange ui.Arrange
---@field origin ui.Pivot
---@field anchor ui.Pivot
---@field axis_invalidated ui.Axis
local LayoutBox = class()

---@class ui.HasLayoutBox
---@field layout_box ui.LayoutBox

---@enum ui.SizeMode
LayoutBox.SizeMode = {
	Fixed = 1,
	Fit = 2,
	Grow = 3,
}

---@enum ui.Arrange
LayoutBox.Arrange = {
	Absolute = 1,
	FlowH = 2,
	FlowV = 3,
}

---@enum ui.Axis
LayoutBox.Axis = {
	None = 0,
	X = 1,
	Y = 2,
	Both = 3,
}

local SizeMode = LayoutBox.SizeMode
local Arrange = LayoutBox.Arrange
local Axis = LayoutBox.Axis

function LayoutBox:new()
	self.x = 0
	self.y = 0
	self.width = 0
	self.height = 0
	self.origin = Pivot.TopLeft
	self.anchor = Pivot.TopLeft
	self.width_mode = SizeMode.Fixed
	self.height_mode = SizeMode.Fixed
	self.padding_left = 0
	self.padding_right = 0
	self.padding_top = 0
	self.padding_bottom = 0
	self.child_gap = 0
	self.arrange = Arrange.Absolute
	self.axis_invalidated = Axis.None
end

---@param axis ui.Axis
function LayoutBox:markDirty(axis)
	self.axis_invalidated = bit.bor(self.axis_invalidated, axis)
end

function LayoutBox:markValid()
	self.axis_invalidated = Axis.None
end

---@return boolean
function LayoutBox:isValid()
	return self.axis_invalidated == Axis.None
end

---@return number
function LayoutBox:getLayoutWidth()
	return self.width - self.padding_left - self.padding_right
end

---@return number
function LayoutBox:getLayoutHeight()
	return self.height - self.padding_top - self.padding_bottom
end

---@return number, number
function LayoutBox:getLayoutDimensions()
	return self:getLayoutWidth(), self:getLayoutHeight()
end

---@param x number
---@param y number
function LayoutBox:setPosition(x, y)
	self.x = x
	self.y = y
	self:markDirty(Axis.Both)
end

---@param width number
function LayoutBox:setWidth(width)
	self.width = width
	self:markDirty(Axis.X)
end

---@param height number
function LayoutBox:setHeight(height)
	self.height = height
	self:markDirty(Axis.Y)
end

---@param width number
---@param height number
function LayoutBox:setDimensions(width, height)
	self.width = width
	self.height = height
	self:markDirty(Axis.Both)
end

return LayoutBox
