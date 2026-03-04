local class = require("class")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis
local Arrange = Enums.Arrange
local SizeMode = Enums.SizeMode
local AlignItems = Enums.AlignItems
local JustifyContent = Enums.JustifyContent

local AbsoluteStrategy = require("ui.layout.strategy.AbsoluteStrategy")
local FlexStrategy = require("ui.layout.strategy.FlexStrategy")
local StackStrategy = require("ui.layout.strategy.StackStrategy")
local WrapStrategy = require("ui.layout.strategy.WrapStrategy")

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field absolute_strategy ui.AbsoluteStrategy
---@field flex_strategy ui.FlexStrategy
---@field stack_strategy ui.StackStrategy
---@field wrap_strategy ui.WrapStrategy
local LayoutEngine = class()

function LayoutEngine:new()
	self.absolute_strategy = AbsoluteStrategy(self)
	self.flex_strategy = FlexStrategy(self)
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

		-- Early-exit: If parent has stable (non-content-derived) size on both axes,
		-- it cannot change size — stop propagation here.
		local parent_x_stable = parent_lb.x.mode == SizeMode.Fixed or parent_lb.x.mode == SizeMode.Percent
		local parent_y_stable = parent_lb.y.mode == SizeMode.Fixed or parent_lb.y.mode == SizeMode.Percent
		if parent_x_stable and parent_y_stable then
			root = parent
			break
		end

		local depends = false

		-- 1. Bottom-Up Dependency: Does the parent's size depend on this child?
		if parent_lb.x.mode == SizeMode.Auto or parent_lb.x.mode == SizeMode.Fit or
			parent_lb.y.mode == SizeMode.Auto or parent_lb.y.mode == SizeMode.Fit then
			depends = true
		end

		-- 2. Top-Down Dependency: Does this child's size depend on the parent?
		if not depends then
			-- Percent sizing explicitly relies on the parent's layout size
			-- Only propagate for Percent children if parent size is content-derived
			if lb.x.mode == SizeMode.Percent or lb.y.mode == SizeMode.Percent then
				if parent_lb.x.mode == SizeMode.Auto or parent_lb.x.mode == SizeMode.Fit or
				   parent_lb.y.mode == SizeMode.Auto or parent_lb.y.mode == SizeMode.Fit then
					depends = true
				end
				-- else: parent size is stable → percent value is stable → no propagation needed
			elseif parent_lb.arrange == Arrange.FlexRow or parent_lb.arrange == Arrange.FlexCol then
				if lb.grow > 0 or lb.shrink > 0 then
					depends = true
				else
					-- Cross-axis stretch check
					local is_row = parent_lb.arrange == Arrange.FlexRow
					local cross_axis = is_row and lb.y or lb.x
					if cross_axis.mode == SizeMode.Auto or cross_axis.mode == SizeMode.Fit then
						local align = lb.align_self or parent_lb.align_items
						if align == AlignItems.Stretch then
							depends = true
						end
					end
				end
			elseif parent_lb.arrange == Arrange.WrapRow or parent_lb.arrange == Arrange.WrapCol then
				if lb.x.mode == SizeMode.Auto or lb.x.mode == SizeMode.Fit then
					depends = true
				elseif lb.y.mode == SizeMode.Auto or lb.y.mode == SizeMode.Fit then
					depends = true
				end
			elseif parent_lb.arrange == Arrange.Stack then
				if (lb.x.mode == SizeMode.Auto or lb.x.mode == SizeMode.Fit) and parent_lb.align_items == AlignItems.Stretch then
					depends = true
				elseif (lb.y.mode == SizeMode.Auto or lb.y.mode == SizeMode.Fit) and parent_lb.justify_content == JustifyContent.Stretch then
					depends = true
				end
			end
		end

		if not depends then
			break
		end

		root = parent
	end

	return root
end

---@param node ui.Node
---@return ui.LayoutStrategy
function LayoutEngine:getStrategy(node)
	local arrange = node.layout_box.arrange

	if arrange == Arrange.FlexRow or arrange == Arrange.FlexCol then
		return self.flex_strategy
	elseif arrange == Arrange.WrapRow or arrange == Arrange.WrapCol then
		return self.wrap_strategy
	elseif arrange == Arrange.Absolute then
		return self.absolute_strategy
	elseif arrange == Arrange.Stack then
		return self.stack_strategy
	end

	-- Default to Stack
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
		self:measure(node, Axis.X)
		self:grow(node, Axis.X)

		self:measure(node, Axis.Y)
		self:grow(node, Axis.Y)

		local target = node.parent and node.parent or node
		self:arrange(target)

		self:markValid(node)
	end

	return layout_roots
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
