local class = require("class")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis
local Arrange = Enums.Arrange
local SizeMode = Enums.SizeMode
local bit_band = bit.band
local bit_bor = bit.bor

local StackStrategy = require("ui.layout.strategy.StackStrategy")
local WrapStrategy = require("ui.layout.strategy.WrapStrategy")

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field stack_strategy ui.StackStrategy
---@field wrap_strategy ui.WrapStrategy
---@field _dirty_subtree_masks {[ui.Node]: ui.Axis}?
local LayoutEngine = class()

function LayoutEngine:new()
	self.stack_strategy = StackStrategy(self)
	self.wrap_strategy = WrapStrategy(self)
end

---@param mode ui.SizeMode
---@return boolean
local function isContentDependentMode(mode)
	return mode == SizeMode.Auto or mode == SizeMode.Fit
end

---@param node ui.Node
---@param axis_idx ui.Axis
---@return boolean
local function shouldPropagateThrough(node, axis_idx)
	local lb = node.layout_box
	local axis_mode = (axis_idx == Axis.X) and lb.x.mode or lb.y.mode
	if isContentDependentMode(axis_mode) then
		return true
	end

	-- Wrap cross-axis can change when main-axis content changes (line breaks).
	if lb.arrange == Arrange.WrapRow and axis_idx == Axis.X then
		return isContentDependentMode(lb.y.mode)
	elseif lb.arrange == Arrange.WrapCol and axis_idx == Axis.Y then
		return isContentDependentMode(lb.x.mode)
	end

	return false
end

---@param node ui.Node
---@param axis_idx ui.Axis
---@return ui.Node
local function findPropagationRoot(node, axis_idx)
	local root = node
	local current = node

	while current.parent do
		local parent = current.parent
		---@cast parent ui.Node
		root = parent

		if not shouldPropagateThrough(parent, axis_idx) then
			break
		end

		current = parent
	end

	return root
end

---@param node ui.Node
---@param root ui.Node
---@param axis_idx ui.Axis
---@param marks {[ui.Node]: ui.Axis}
local function markPathToRoot(node, root, axis_idx, marks)
	local current = node
	while current do
		marks[current] = bit_bor(marks[current] or Axis.None, axis_idx)
		if current == root then
			break
		end
		current = current.parent
	end
end

---@param root ui.Node
---@param forced_marks {[ui.Node]: ui.Axis}
---@param dirty_masks {[ui.Node]: ui.Axis}
---@param inherited_dirty ui.Axis?
---@return ui.Axis
local function buildDirtySubtreeMask(root, forced_marks, dirty_masks, inherited_dirty)
	local node_dirty = root.layout_box.axis_invalidated
	local propagate_dirty = bit_bor(inherited_dirty or Axis.None, node_dirty)
	local mask = bit_bor(propagate_dirty, forced_marks[root] or Axis.None)

	for _, child in ipairs(root.children) do
		mask = bit_bor(mask, buildDirtySubtreeMask(child, forced_marks, dirty_masks, propagate_dirty))
	end

	dirty_masks[root] = mask
	return mask
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
	---@type {[ui.Node]: ui.Axis}
	local forced_path_marks = {}

	-- Collect unique layout roots using per-axis propagation.
	for _, node in ipairs(dirty_nodes) do
		local root_x = findPropagationRoot(node, Axis.X)
		local root_y = findPropagationRoot(node, Axis.Y)
		layout_roots[root_x] = true
		layout_roots[root_y] = true
		markPathToRoot(node, root_x, Axis.X, forced_path_marks)
		markPathToRoot(node, root_y, Axis.Y, forced_path_marks)
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

	---@type {[ui.Node]: ui.Axis}
	local dirty_subtree_masks = {}
	for root, _ in pairs(layout_roots) do
		buildDirtySubtreeMask(root, forced_path_marks, dirty_subtree_masks, Axis.None)
	end
	self._dirty_subtree_masks = dirty_subtree_masks

	for node, _ in pairs(layout_roots) do
		local measured_x = self:measure(node, Axis.X)
		local measured_y = self:measure(node, Axis.Y)
		self:arrange(node, measured_x or measured_y)
	end
	self._dirty_subtree_masks = nil

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
---@param axis_idx ui.Axis
---@param dependency_dirty boolean?
---@return boolean measured
function LayoutEngine:measureChild(node, axis_idx, dependency_dirty)
	if not self:needsMeasure(node, axis_idx, dependency_dirty) then
		return false
	end
	return self:measure(node, axis_idx, dependency_dirty)
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
	local dirty_subtree_masks = self._dirty_subtree_masks
	if dirty_subtree_masks then
		for _, child in ipairs(node.children) do
			if bit_band(dirty_subtree_masks[child] or Axis.None, axis) ~= 0 then
				return true
			end
		end
		return false
	end

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
	local dirty_subtree_masks = self._dirty_subtree_masks
	if dirty_subtree_masks and bit_band(dirty_subtree_masks[node] or Axis.None, axis) == 0 then
		return false
	end

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
	local dirty_subtree_masks = self._dirty_subtree_masks
	if dirty_subtree_masks and bit_band(dirty_subtree_masks[node] or Axis.None, Axis.Both) == 0 then
		return false
	end

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
