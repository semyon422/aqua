local class = require("class")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis
local Arrange = Enums.Arrange
local SizeMode = Enums.SizeMode
local bit_band = bit.band

local StackStrategy = require("ui.layout.strategy.StackStrategy")
local WrapStrategy = require("ui.layout.strategy.WrapStrategy")

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field stack_strategy ui.StackStrategy
---@field wrap_strategy ui.WrapStrategy
local LayoutEngine = class()

function LayoutEngine:new()
	self.stack_strategy = StackStrategy(self)
	self.wrap_strategy = WrapStrategy(self)
end

---@param node ui.Node
---@return ui.Node
local function findStableRoot(node)
	local root = node

	while root.parent do
		local parent = root.parent
		---@cast parent ui.Node
		local lb = root.layout_box
		local parent_lb = parent.layout_box

		local parent_stable =
			(parent_lb.x.mode == SizeMode.Fixed or parent_lb.x.mode == SizeMode.Percent) and
			(parent_lb.y.mode == SizeMode.Fixed or parent_lb.y.mode == SizeMode.Percent)

		if parent_stable then
			root = parent
			break
		end

		local depends =
			parent_lb.x.mode == SizeMode.Auto or parent_lb.x.mode == SizeMode.Fit or
			parent_lb.y.mode == SizeMode.Auto or parent_lb.y.mode == SizeMode.Fit or
			lb.x.mode == SizeMode.Percent or lb.y.mode == SizeMode.Percent

		if not depends then break end

		root = parent
	end

	return root
end

---@param node ui.Node
---@return ui.LayoutStrategy
function LayoutEngine:getStrategy(node)
	local arrange = node.layout_box.arrange
	if arrange == Arrange.WrapRow or arrange == Arrange.WrapCol then
		return self.wrap_strategy
	end
	return self.stack_strategy
end

---@param dirty_nodes ui.Node[]
---@return {[ui.Node]: boolean}? updated_layout_roots
function LayoutEngine:updateLayout(dirty_nodes)
	if #dirty_nodes == 0 then
		return
	end

	---@type {[ui.Node]: boolean}
	local layout_roots = {}

	-- Collect unique layout roots
	for _, node in ipairs(dirty_nodes) do
		local root = findStableRoot(node)
		layout_roots[root] = true
	end

	-- Filter out roots that are descendants of other roots
	-- If root A is an ancestor of root B, we only need to layout from A
	local root_count = 0
	for _ in pairs(layout_roots) do root_count = root_count + 1 end

	if root_count > 1 then
		local filtered_roots = {}
		for root1, _ in pairs(layout_roots) do
			local is_descendant = false
			local curr = root1.parent
			while curr do
				if layout_roots[curr] then
					is_descendant = true
					break
				end
				curr = curr.parent
			end
			if not is_descendant then
				filtered_roots[root1] = true
			end
		end
		layout_roots = filtered_roots
	end

	-- If root is a node with no parent, use it as the only layout root
	for node, _ in pairs(layout_roots) do
		if not node.parent then
			layout_roots = {}
			layout_roots[node] = true
			break
		end
	end

	for node, _ in pairs(layout_roots) do
		local measured_x = self:measure(node, Axis.X)
		local measured_y = self:measure(node, Axis.Y)
		self:arrange(node, measured_x or measured_y)
	end

	return layout_roots
end

---@param node ui.Node
---@param axis_idx ui.Axis
---@param dependency_dirty boolean?
---@return boolean measured
function LayoutEngine:measure(node, axis_idx, dependency_dirty)
	if not self:needsMeasure(node, axis_idx, dependency_dirty) then
		return false
	end

	local strategy = self:getStrategy(node)
	strategy:measure(node, axis_idx, dependency_dirty)
	self:markValid(node, axis_idx)
	return true
end

---@param node ui.Node
---@param dependency_dirty boolean?
function LayoutEngine:arrange(node, dependency_dirty)
	if not self:needsArrange(node, dependency_dirty) then
		return
	end

	local strategy = self:getStrategy(node)
	strategy:arrange(node, dependency_dirty)
	self:markValid(node, Axis.Both)
end

---@param node ui.Node
---@param axis ui.Axis
function LayoutEngine:isNodeDirty(node, axis)
	return bit_band(node.layout_box.axis_invalidated, axis) ~= 0
end

---@param node ui.Node
---@param axis ui.Axis
function LayoutEngine:hasDirtyDescendant(node, axis)
	for _, child in ipairs(node.children) do
		if self:isNodeDirty(child, axis) or self:hasDirtyDescendant(child, axis) then
			return true
		end
	end

	return false
end

---@param node ui.Node
---@param axis ui.Axis
---@param dependency_dirty boolean?
function LayoutEngine:needsMeasure(node, axis, dependency_dirty)
	if dependency_dirty then
		return true
	end

	if self:isNodeDirty(node, axis) then
		return true
	end

	return self:hasDirtyDescendant(node, axis)
end

---@param node ui.Node
---@param dependency_dirty boolean?
function LayoutEngine:needsArrange(node, dependency_dirty)
	if dependency_dirty then
		return true
	end

	if self:isNodeDirty(node, Axis.Both) then
		return true
	end

	return self:hasDirtyDescendant(node, Axis.Both)
end

---@param node ui.Node
---@param axis ui.Axis
function LayoutEngine:markValid(node, axis)
	node.layout_box.axis_invalidated = bit_band(node.layout_box.axis_invalidated, bit.bnot(axis))
end

return LayoutEngine
