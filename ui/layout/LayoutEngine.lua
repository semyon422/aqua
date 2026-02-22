local class = require("class")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis
local SizeMode = Enums.SizeMode
local Arrange = Enums.Arrange
local bit_band = bit.band

local AbsoluteStrategy = require("ui.layout.strategy.AbsoluteStrategy")
local FlexStrategy = require("ui.layout.strategy.FlexStrategy")
local GridStrategy = require("ui.layout.strategy.GridStrategy")

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field absolute_strategy ui.AbsoluteStrategy
---@field flex_strategy ui.FlexStrategy
---@field grid_strategy ui.GridStrategy
local LayoutEngine = class()

function LayoutEngine:new()
	self.absolute_strategy = AbsoluteStrategy(self)
	self.flex_strategy = FlexStrategy(self)
	self.grid_strategy = GridStrategy(self)
end

---@param node ui.Node
---@return ui.LayoutStrategy
function LayoutEngine:getStrategy(node)
	local arrange = node.layout_box.arrange

	if arrange == Arrange.Absolute then
		return self.absolute_strategy
	elseif arrange == Arrange.FlexRow or arrange == Arrange.FlexCol then
		return self.flex_strategy
	elseif arrange == Arrange.Grid then
		return self.grid_strategy
	end

	-- Default to absolute
	return self.absolute_strategy
end

---@param dirty_nodes ui.Node[]
---@return {[ui.Node]: boolean}? updated_layout_roots
function LayoutEngine:updateLayout(dirty_nodes)
	if #dirty_nodes == 0 then
		return
	end

	---@type {[ui.Node]: boolean}
	local layout_roots = {}

	for _, v in ipairs(dirty_nodes) do
		local node = self:findLayoutBoundary(v, v.layout_box.axis_invalidated)
		layout_roots[node] = true

		if not node.parent then
			layout_roots = {}
			layout_roots[node] = true
			break
		end
	end

	for node, _ in pairs(layout_roots) do
		-- Always measure both axes for layout roots
		-- They may have been found via findLayoutBoundary even if not explicitly dirty
		self:measure(node, Axis.X)
		self:grow(node, Axis.X)

		self:measure(node, Axis.Y)
		self:grow(node, Axis.Y)

		local target = node.parent and node.parent or node
		self:arrange(target)

		-- Mark the entire subtree as valid after layout completes
		self:markValid(node)
	end

	return layout_roots
end

---Find a node that can handle relayout
---@param node ui.Node
---@param axis ui.Axis
function LayoutEngine:findLayoutBoundary(node, axis)
	if not node.parent then
		return node
	end

	if self:isStableBoundary(node.parent.layout_box, axis) then
		return node.parent
	end

	return self:findLayoutBoundary(node.parent, axis)
end

---Determine if a node has fixed dimensions for the requested axis
---@param layout_box ui.LayoutBox
---@param axis ui.Axis
---@return boolean
function LayoutEngine:isStableBoundary(layout_box, axis)
	if bit_band(layout_box.axis_invalidated, axis) ~= 0 then
		return true
	end

	local x_stable = layout_box.x.mode == SizeMode.Fixed or layout_box.x.mode == SizeMode.Percent
	local y_stable = layout_box.y.mode == SizeMode.Fixed or layout_box.y.mode == SizeMode.Percent

	if bit_band(axis, Axis.X) ~= 0 and not x_stable then
		return false
	end
	if bit_band(axis, Axis.Y) ~= 0 and not y_stable then
		return false
	end

	return true
end

---@param node ui.Node
---@param axis_idx ui.Axis
function LayoutEngine:measure(node, axis_idx)
	local strategy = self:getStrategy(node)
	strategy:measure(node, axis_idx)
end

---@param node ui.Node
---@param axis_idx ui.Axis
function LayoutEngine:grow(node, axis_idx)
	local strategy = self:getStrategy(node)
	strategy:grow(node, axis_idx)
end

---@param node ui.Node
function LayoutEngine:arrange(node)
	local strategy = self:getStrategy(node)
	strategy:arrange(node)
end

---Mark a node and all its children as valid (layout is up-to-date)
---@param node ui.Node
function LayoutEngine:markValid(node)
	node.layout_box:markValid()
	for _, child in ipairs(node.children) do
		self:markValid(child)
	end
end

return LayoutEngine
