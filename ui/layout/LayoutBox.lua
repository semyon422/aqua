local class = require("class")
local LayoutAxis = require("ui.layout.LayoutAxis")
local Enums = require("ui.layout.Enums")

---@class ui.LayoutBox
---@operator call: ui.LayoutBox
---@field x ui.LayoutAxis
---@field y ui.LayoutAxis
---@field child_gap number
---@field arrange ui.Arrange
---@field justify_content ui.JustifyContent
---@field align_items ui.AlignItems
---@field align_self ui.AlignItems?
---@field axis_invalidated ui.Axis
local LayoutBox = class()

---@class ui.HasLayoutBox
---@field layout_box ui.LayoutBox

LayoutBox.Pivot = Enums.Pivot
LayoutBox.SizeMode = Enums.SizeMode
LayoutBox.Arrange = Enums.Arrange
LayoutBox.Axis = Enums.Axis
LayoutBox.JustifyContent = Enums.JustifyContent
LayoutBox.AlignItems = Enums.AlignItems

local SizeMode = Enums.SizeMode
local Arrange = Enums.Arrange
local Axis = Enums.Axis
local JustifyContent = Enums.JustifyContent
local AlignItems = Enums.AlignItems

function LayoutBox:new()
	self.x = LayoutAxis()
	self.y = LayoutAxis()

	self.grow = 0
	self.child_gap = 0
	self.reversed = false
	self.arrange = Arrange.Absolute
	self.justify_content = JustifyContent.Start
	self.align_items = AlignItems.Start
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
	return self.x.size - self.x.padding_start - self.x.padding_end
end

---@return number
function LayoutBox:getLayoutHeight()
	return self.y.size - self.y.padding_start - self.y.padding_end
end

---@return number, number
function LayoutBox:getLayoutDimensions()
	return self:getLayoutWidth(), self:getLayoutHeight()
end

---@param x number
---@param y number
function LayoutBox:setPosition(x, y)
	self.x.pos = x
	self.y.pos = y
	self:markDirty(Axis.Both)
end

---@param reversed boolean
function LayoutBox:setReversed(reversed)
	if self.reversed == reversed then
		return
	end
	self.reversed = reversed
	self:markDirty(Axis.Both)
end

---@param width number
function LayoutBox:setWidth(width)
	self.x:setSize(width)
	self.x.mode = SizeMode.Fixed
	self:markDirty(Axis.X)
end

---@param percent number
function LayoutBox:setWidthPercent(percent)
	self.x:setPercent(percent)
	self:markDirty(Axis.X)
end

function LayoutBox:setWidthAuto()
	self.x.mode = SizeMode.Auto
	self:markDirty(Axis.X)
end

function LayoutBox:setWidthFit()
	self.x.mode = SizeMode.Fit
	self:markDirty(Axis.X)
end

---@param height number
function LayoutBox:setHeight(height)
	self.y:setSize(height)
	self.y.mode = SizeMode.Fixed
	self:markDirty(Axis.Y)
end

---@param percent number
function LayoutBox:setHeightPercent(percent)
	self.y:setPercent(percent)
	self:markDirty(Axis.Y)
end

function LayoutBox:setHeightAuto()
	self.y.mode = SizeMode.Auto
	self:markDirty(Axis.Y)
end

function LayoutBox:setHeightFit()
	self.y.mode = SizeMode.Fit
	self:markDirty(Axis.Y)
end

---@param width number
---@param height number
function LayoutBox:setDimensions(width, height)
	self:setWidth(width)
	self:setHeight(height)
end

---@param min_width number
---@param max_width number
function LayoutBox:setWidthLimits(min_width, max_width)
	self.x:setLimits(min_width, max_width)
	self:markDirty(Axis.X)
end

---@param min number
function LayoutBox:setMinWidth(min)
	self.x:setMin(min)
	self:markDirty(Axis.X)
end

---@param max number
function LayoutBox:setMaxWidth(max)
	self.x:setMax(max)
	self:markDirty(Axis.X)
end

---@param min_height number
---@param max_height number
function LayoutBox:setHeightLimits(min_height, max_height)
	self.y:setLimits(min_height, max_height)
	self:markDirty(Axis.Y)
end

---@param min number
function LayoutBox:setMinHeight(min)
	self.y:setMin(min)
	self:markDirty(Axis.Y)
end

---@param max number
function LayoutBox:setMaxHeight(max)
	self.y:setMax(max)
	self:markDirty(Axis.Y)
end

---@param grow number
function LayoutBox:setGrow(grow)
	if self.grow == grow then
		return
	end
	self.grow = grow
	self:markDirty(Axis.Both)
end

---@param arrange ui.Arrange
function LayoutBox:setArrange(arrange)
	if self.arrange == arrange then
		return
	end
	self.arrange = arrange
	self:markDirty(Axis.Both)
end

---@param align ui.AlignItems
function LayoutBox:setAlignItems(align)
	if self.align_items == align then
		return
	end
	self.align_items = align
	self:markDirty(Axis.Both)
end

---@param align ui.AlignItems?
function LayoutBox:setAlignSelf(align)
	if self.align_self == align then
		return
	end
	self.align_self = align
	self:markDirty(Axis.Both)
end

---@param justify_content ui.JustifyContent
function LayoutBox:setJustifyContent(justify_content)
	if self.justify_content	== justify_content then
		return
	end
	self.justify_content = justify_content
	self:markDirty(Axis.Both)
end

---@param gap number
function LayoutBox:setChildGap(gap)
	self.child_gap = gap
	self:markDirty(Axis.Both) -- TODO: You only need to mark dirty one of the axies
end

---@param t [number, number, number, number]
function LayoutBox:setPaddings(t)
	self.y.padding_start = t[1]
	self.x.padding_end = t[2]
	self.y.padding_end = t[3]
	self.x.padding_start = t[4]
	self:markDirty(Axis.Both)
end

return LayoutBox
