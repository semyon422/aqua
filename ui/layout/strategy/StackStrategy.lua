local LayoutStrategy = require("ui.layout.strategy.LayoutStrategy")
local Enums = require("ui.layout.Enums")
local math_util = require("math_util")

local Axis = Enums.Axis
local SizeMode = Enums.SizeMode
local JustifyContent = Enums.JustifyContent
local AlignItems = Enums.AlignItems
local math_clamp = math_util.clamp
local math_max = math.max
local math_min = math.min

---@class ui.StackStrategy: ui.LayoutStrategy
---@operator call: ui.StackStrategy
local StackStrategy = LayoutStrategy + {}

---Measure all children and set node size
---Stack size is the max() of its children's sizes (plus margins), plus paddings
---@param node ui.Node
---@param axis_idx ui.Axis
function StackStrategy:measure(node, axis_idx)
	local axis = self:getAxis(node, axis_idx)
	local min_s = axis.min_size
	local max_s = axis.max_size

	-- Fixed or Percent: use predefined size
	if axis.mode == SizeMode.Fixed or axis.mode == SizeMode.Percent then
		local s = axis.preferred_size
		if axis.mode == SizeMode.Percent and node.parent then
			local parent_axis = self:getAxis(node.parent, axis_idx)
			s = s * (parent_axis:getLayoutSize() - axis:getTotalMargin())
		end
		axis.size = math_clamp(s, min_s, max_s)

		for _, child in ipairs(node.children) do
			self.engine:measure(child, axis_idx)
		end
		return
	end

	-- Auto/Fit: calculate size from children or intrinsic size
	local s = 0.0

	if #node.children == 0 then
		-- Leaf node: use intrinsic size if available
		local constraint = nil
		local constrained = false

		if axis_idx == Axis.Y then
			-- For Y axis, pass width as constraint (for text wrapping)
			local x_axis = node.layout_box.x
			if x_axis.mode == SizeMode.Auto or x_axis.mode == SizeMode.Fit then
				-- Node's X is not fixed - use parent's content width as constraint
				-- The parent's size may have been set by grow/stretch phase
				if node.parent then
					local parent_x = node.parent.layout_box.x
					constraint = parent_x.size - parent_x.padding_start - parent_x.padding_end
						- x_axis.margin_start - x_axis.margin_end
				end
			else
				-- Node's X is fixed/percent - use its own size
				constraint = x_axis.size
			end
		elseif axis_idx == Axis.X then
			-- For X axis, constrain intrinsic width to parent's available width
			-- Only constrain if parent has a Fixed/Percent size (independent of children)
			if node.parent then
				local parent_x = node.parent.layout_box.x
				if parent_x.mode == SizeMode.Fixed or parent_x.mode == SizeMode.Percent then
					local available = parent_x.size - parent_x.padding_start - parent_x.padding_end
						- axis.margin_start - axis.margin_end
					local intrinsic_width = self:getIntrinsicSize(node, axis_idx, nil) or 0
					-- Constrain to parent's available width (text should wrap, not overflow)
					s = math_min(intrinsic_width, available)
					constrained = true
				end
			end
		end

		if not constrained then
			s = self:getIntrinsicSize(node, axis_idx, constraint) or 0
		end
	else
		-- Container: size is the max of children's sizes
		-- First pass: measure non-Percent children
		for _, child in ipairs(node.children) do
			local child_axis = self:getAxis(child, axis_idx)
			if child_axis.mode ~= SizeMode.Percent then
				self.engine:measure(child, axis_idx)
				s = math_max(s, child_axis.size + child_axis:getTotalMargin())
			end
		end

		-- Set preliminary size for Percent children to reference
		local base_size = axis.padding_start + s + axis.padding_end
		axis.size = math_clamp(base_size, min_s, max_s)

		-- Second pass: measure Percent children
		for _, child in ipairs(node.children) do
			local child_axis = self:getAxis(child, axis_idx)
			if child_axis.mode == SizeMode.Percent then
				self.engine:measure(child, axis_idx)
				s = math_max(s, child_axis.size + child_axis:getTotalMargin())
			end
		end
	end

	s = axis.padding_start + s + axis.padding_end
	axis.size = math_clamp(s, min_s, max_s)
end

---Distribute extra space - Stacks do not "grow" children proportionally
---However, if align_items == Stretch (X) or justify_content == Stretch (Y),
---modify the child's size to fill available space
---@param node ui.Node
---@param axis_idx ui.Axis
function StackStrategy:grow(node, axis_idx)
	if #node.children == 0 then
		return
	end

	local layout_box = node.layout_box
	local axis = self:getAxis(node, axis_idx)
	local available_space = axis:getLayoutSize() -- Already excludes padding

	for _, child in ipairs(node.children) do
		local child_axis = self:getAxis(child, axis_idx)

		-- Handle percent sizing
		if child_axis.mode == SizeMode.Percent then
			local parent_size = axis:getLayoutSize()
			local s = child_axis.preferred_size * (parent_size - child_axis:getTotalMargin())
			child_axis.size = math_clamp(s, child_axis.min_size, child_axis.max_size)
		end

		-- Determine which alignment to use for this axis
		-- align_items controls X-axis, justify_content controls Y-axis
		local stretch_alignment ---@type integer Either Align or Justify
		if axis_idx == Axis.X then
			stretch_alignment = child.layout_box.align_self or layout_box.align_items
		else
			stretch_alignment = child.layout_box.justify_self or layout_box.justify_content
		end

		-- Apply stretch if alignment is Stretch and child has Auto size
		local stretched_size = available_space - child_axis:getTotalMargin()
		if child_axis.mode == SizeMode.Auto then
			if (stretch_alignment == AlignItems.Stretch or stretch_alignment == JustifyContent.Stretch) then
				child_axis.size = math_clamp(stretched_size, child_axis.min_size, child_axis.max_size)
			elseif child_axis.size > stretched_size and stretched_size > 0 then
				-- Even if not stretching, constrain to available space to prevent overflow and ensure wrapping
				child_axis.size = math_clamp(stretched_size, child_axis.min_size, child_axis.max_size)
			end
		elseif child_axis.mode == SizeMode.Fit then
			if child_axis.size > stretched_size and stretched_size > 0 then
				-- Constrain Fit mode if it overflows and we have positive space
				child_axis.size = math_clamp(stretched_size, child_axis.min_size, child_axis.max_size)
			end
		end
	end

	-- Recurse into children
	for _, child in ipairs(node.children) do
		self.engine:grow(child, axis_idx)
	end
end

---Position all children - they all overlap (Z-axis stacking)
---Use align_items for X-axis alignment, justify_content for Y-axis alignment
---@param node ui.Node
function StackStrategy:arrange(node)
	local layout_box = node.layout_box
	local node_x = layout_box.x
	local node_y = layout_box.y

	-- getLayoutSize() already excludes padding
	local available_width = node_x:getLayoutSize()
	local available_height = node_y:getLayoutSize()

	for _, child in ipairs(node.children) do
		local child_x = child.layout_box.x
		local child_y = child.layout_box.y

		-- X-axis position (controlled by align_items / align_self)
		local x_pos = self:calculatePosition(
			child.layout_box.align_self or layout_box.align_items,
			node_x.padding_start,
			available_width,
			child_x.size,
			child_x.margin_start,
			child_x.margin_end
		)
		child_x.pos = x_pos

		-- Y-axis position (controlled by justify_content / justify_self)
		local y_pos = self:calculatePosition(
			child.layout_box.justify_self or layout_box.justify_content,
			node_y.padding_start,
			available_height,
			child_y.size,
			child_y.margin_start,
			child_y.margin_end
		)
		child_y.pos = y_pos

		self:arrangeChild(child)
	end
end

---Calculate position based on alignment
---@param alignment ui.AlignItems|ui.JustifyContent
---@param padding_start number
---@param available_space number
---@param child_size number
---@param margin_start number
---@param margin_end number
---@return number
function StackStrategy:calculatePosition(alignment, padding_start, available_space, child_size, margin_start, margin_end)
	if alignment == AlignItems.Start or alignment == JustifyContent.Start then
		-- Start: pos = padding_start + margin_start
		return padding_start + margin_start
	elseif alignment == AlignItems.Center or alignment == JustifyContent.Center then
		-- Center: pos = padding_start + (available_space - child_size) / 2
		-- Note: margins are already accounted for in available_space calculation
		return padding_start + (available_space - child_size - margin_start - margin_end) / 2 + margin_start
	elseif alignment == AlignItems.End or alignment == JustifyContent.End then
		-- End: pos = padding_start + available_space - child_size - margin_end
		return padding_start + available_space - child_size - margin_end
	elseif alignment == AlignItems.Stretch or alignment == JustifyContent.Stretch then
		-- Stretch: same as Start for positioning (size was already modified in grow)
		return padding_start + margin_start
	end

	-- Default to Start
	return padding_start + margin_start
end

return StackStrategy
