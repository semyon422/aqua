local table_util = require("table_util")
local math_util = require("math_util")
local LayoutStrategy = require("ui.layout.strategy.LayoutStrategy")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis
local SizeMode = Enums.SizeMode
local Arrange = Enums.Arrange
local JustifyContent = Enums.JustifyContent
local AlignItems = Enums.AlignItems
local math_clamp = math_util.clamp
local math_max = math.max

---@class ui.FlexStrategy: ui.LayoutStrategy
---@operator call: ui.FlexStrategy
local FlexStrategy = LayoutStrategy + {}

-- Reusable tables for GC optimization
local growables = {} ---@type ui.Node[]
local active_children = {} ---@type ui.Node[]
local next_active_children = {} ---@type ui.Node[]

---Check if axis is the main axis for this flex direction
---@param layout_box ui.LayoutBox
---@param axis_idx ui.Axis
---@return boolean
local function isMainAxis(layout_box, axis_idx)
	return (
		(layout_box.arrange == Arrange.FlexRow and axis_idx == Axis.X) or
		(layout_box.arrange == Arrange.FlexCol and axis_idx == Axis.Y)
	)
end

---Measure all children and set node size
---@param node ui.Node
---@param axis_idx ui.Axis
function FlexStrategy:measure(node, axis_idx)
	local layout_box = node.layout_box
	local axis = self:getAxis(node, axis_idx)
	local min_s = axis.min_size
	local max_s = axis.max_size

	-- Fixed or Percent: use predefined size
	if axis.mode == SizeMode.Fixed or axis.mode == SizeMode.Percent then
		local s = axis.preferred_size
		if axis.mode == SizeMode.Percent and node.parent then
			local parent_axis = self:getAxis(node.parent, axis_idx)
			s = s * parent_axis:getLayoutSize()
		end
		axis.size = math_clamp(s, min_s, max_s)

		for _, child in ipairs(node.children) do
			self:measure(child, axis_idx)
		end
		return
	end

	-- Auto/Fit: calculate size from children or intrinsic size
	local is_main_axis = isMainAxis(layout_box, axis_idx)
	local s = 0.0
	local child_count = 0

	if #node.children == 0 then
		-- Leaf node: use intrinsic size if available
		local constraint = nil
		if axis_idx == Axis.Y then
			-- For Y axis, pass width as constraint (for text wrapping)
			constraint = node.layout_box.x.size
		end
		s = self:getIntrinsicSize(node, axis_idx, constraint) or 0
	else
		if is_main_axis then
			-- Main axis: sum of children + gaps
			for _, child in ipairs(node.children) do
				self:measure(child, axis_idx)
				local child_axis = self:getAxis(child, axis_idx)
				s = s + child_axis.size + child_axis:getTotalMargin()
				child_count = child_count + 1
			end
			s = s + layout_box.child_gap * math_max(0, child_count - 1)
		else
			-- Cross axis: max of children
			for _, child in ipairs(node.children) do
				self:measure(child, axis_idx)
				local child_axis = self:getAxis(child, axis_idx)
				s = math_max(s, child_axis.size + child_axis:getTotalMargin())
			end
		end
	end

	s = axis.padding_start + s + axis.padding_end
	axis.size = math_clamp(s, min_s, max_s)
end

---Distribute extra space to growing children
---@param node ui.Node
---@param axis_idx ui.Axis
function FlexStrategy:grow(node, axis_idx)
	if #node.children == 0 then
		return
	end

	local layout_box = node.layout_box
	local axis = self:getAxis(node, axis_idx)
	local is_main_axis = isMainAxis(layout_box, axis_idx)

	table_util.clear(growables)

	local available_space = axis:getLayoutSize()
	local total_grow = 0
	local child_count = 0

	for _, child in ipairs(node.children) do
		local child_axis = self:getAxis(child, axis_idx)
		child_count = child_count + 1

		-- Handle percent sizing
		if child_axis.mode == SizeMode.Percent then
			local parent_size = axis:getLayoutSize()
			local s = child_axis.preferred_size * parent_size
			child_axis.size = math_clamp(s, child_axis.min_size, child_axis.max_size)
		end

		if is_main_axis then
			available_space = available_space - child_axis.size - child_axis:getTotalMargin()

			if child.layout_box.grow > 0 then
				table.insert(growables, child)
				total_grow = total_grow + child.layout_box.grow
			end
		else
			-- Cross axis: stretch alignment
			local align = child.layout_box.align_self or layout_box.align_items
			if align == AlignItems.Stretch and child_axis.mode == SizeMode.Auto then
				table.insert(growables, child)
			end
		end
	end

	if is_main_axis then
		available_space = available_space - layout_box.child_gap * math_max(0, child_count - 1)
	end

	if #growables > 0 and available_space > 0 then
		if is_main_axis then
			self:distributeFlexSpace(growables, available_space, total_grow, axis_idx)
		else
			-- Stretch cross axis
			for _, child in ipairs(growables) do
				local child_axis = self:getAxis(child, axis_idx)
				local new_size = math_clamp(available_space, child_axis.min_size, child_axis.max_size)
				child_axis.size = new_size
			end
		end
	end

	-- Recurse into children
	for _, child in ipairs(node.children) do
		self:grow(child, axis_idx)
	end
end

---Distribute available space among flex items
---@param children ui.Node[]
---@param available_space number
---@param total_grow number
---@param axis_idx ui.Axis
function FlexStrategy:distributeFlexSpace(children, available_space, total_grow, axis_idx)
	local remaining_space = available_space
	local current_total_grow = total_grow

	table_util.clear(active_children)
	for i = 1, #children do
		active_children[i] = children[i]
	end

	while #active_children > 0 and remaining_space > 0 and current_total_grow > 0 do
		table_util.clear(next_active_children)
		local next_total_grow = 0
		local any_capped = false
		local space_to_distribute = remaining_space

		for _, child in ipairs(active_children) do
			local child_axis = self:getAxis(child, axis_idx)
			local grow_factor = child.layout_box.grow / current_total_grow
			local add_size = space_to_distribute * grow_factor
			local target_size = child_axis.size + add_size

			if target_size > child_axis.max_size then
				local actually_added = child_axis.max_size - child_axis.size
				child_axis.size = child_axis.max_size
				remaining_space = remaining_space - actually_added
				any_capped = true
			else
				next_active_children[#next_active_children + 1] = child
				next_total_grow = next_total_grow + child.layout_box.grow
			end
		end

		if not any_capped then
			for _, child in ipairs(active_children) do
				local child_axis = self:getAxis(child, axis_idx)
				local grow_factor = child.layout_box.grow / current_total_grow
				child_axis.size = child_axis.size + remaining_space * grow_factor
			end
			remaining_space = 0
			break
		end

		-- Swap active and next_active
		next_active_children, active_children = active_children, next_active_children
		current_total_grow = next_total_grow
	end
end

---Position all children
---@param node ui.Node
function FlexStrategy:arrange(node)
	local layout_box = node.layout_box

	local main_axis_idx = (layout_box.arrange == Arrange.FlexRow) and Axis.X or Axis.Y
	local cross_axis_idx = (layout_box.arrange == Arrange.FlexRow) and Axis.Y or Axis.X

	local main_axis = self:getAxis(node, main_axis_idx)
	local cross_axis = self:getAxis(node, cross_axis_idx)

	local justify = layout_box.justify_content
	local align = layout_box.align_items

	-- Count children and calculate total main size
	local child_count = 0
	local total_main_size = 0
	for _, child in ipairs(node.children) do
		child_count = child_count + 1
		local child_main = self:getAxis(child, main_axis_idx)
		total_main_size = total_main_size + child_main.size + child_main:getTotalMargin()
	end

	local available_main = main_axis:getLayoutSize()
	local available_cross = cross_axis:getLayoutSize()

	local pos = main_axis.padding_start
	local gap = layout_box.child_gap

	-- LLS bug
	---@cast child_count integer
	---@cast total_main_size number

	if justify == JustifyContent.End then
		pos = available_main - total_main_size - gap * (child_count - 1) + main_axis.padding_start
	elseif justify == JustifyContent.Center then
		pos = (available_main - total_main_size - gap * (child_count - 1)) / 2 + main_axis.padding_start
	elseif justify == JustifyContent.SpaceBetween and child_count > 1 then
		gap = (available_main - total_main_size) / (child_count - 1)
		pos = main_axis.padding_start
	end

	-- Handle reversed order
	local start_idx = 1
	local end_idx = #node.children
	local step = 1
	if layout_box.reversed then
		start_idx = #node.children
		end_idx = 1
		step = -1
	end

	for i = start_idx, end_idx, step do
		local child = node.children[i]

		local child_main = self:getAxis(child, main_axis_idx)
		local child_cross = self:getAxis(child, cross_axis_idx)

		-- Position on main axis (include margin_start)
		child_main.pos = pos + child_main.margin_start

		-- Position on cross axis
		local child_align = child.layout_box.align_self or align
		local cross_pos = cross_axis.padding_start + child_cross.margin_start

		if child_align == AlignItems.End then
			cross_pos = available_cross - child_cross.size - child_cross.margin_end
		elseif child_align == AlignItems.Center then
			cross_pos = (available_cross - child_cross.size - child_cross:getTotalMargin()) / 2 + child_cross.margin_start
		end

		child_cross.pos = cross_pos

		self:arrange(child)

		pos = pos + child_main.size + child_main:getTotalMargin() + gap
	end
end

return FlexStrategy
