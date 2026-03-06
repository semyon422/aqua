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

---@class ui.WrapStrategy: ui.LayoutStrategy
---@operator call: ui.WrapStrategy
local WrapStrategy = LayoutStrategy + {}

local function isMainAxis(layout_box, axis_idx)
	return (
		(layout_box.arrange == Arrange.WrapRow and axis_idx == Axis.X) or
		(layout_box.arrange == Arrange.WrapCol and axis_idx == Axis.Y)
	)
end

---@param dependency_dirty boolean?
function WrapStrategy:measure(node, axis_idx, dependency_dirty)
	local layout_box = node.layout_box
	local axis = self:getAxis(node, axis_idx)
	local min_s = axis.min_size
	local max_s = axis.max_size
	local parent_dirty_axis = dependency_dirty or self.engine:isNodeDirty(node, axis_idx)

	if axis.mode == SizeMode.Fixed or axis.mode == SizeMode.Percent then
		local s = axis.preferred_size
		if axis.mode == SizeMode.Percent and node.parent then
			local parent_axis = self:getAxis(node.parent, axis_idx)
			s = s * (parent_axis:getLayoutSize() - axis:getTotalMargin())
		end
		axis.size = math_clamp(s, min_s, max_s)

		for _, child in ipairs(node.children) do
			self.engine:measure(child, axis_idx, parent_dirty_axis)
		end
		return
	end

	local is_main = isMainAxis(layout_box, axis_idx)

	if is_main then
		local s = 0
		local child_count = 0
		for _, child in ipairs(node.children) do
			local child_axis = self:getAxis(child, axis_idx)
			if child_axis.mode ~= SizeMode.Percent then
				self.engine:measure(child, axis_idx, parent_dirty_axis)
				s = s + child_axis.size + child_axis:getTotalMargin()
				child_count = child_count + 1
			end
		end

		local base_size = axis.padding_start + s + axis.padding_end
		axis.size = math_clamp(base_size, min_s, max_s)

		for _, child in ipairs(node.children) do
			local child_axis = self:getAxis(child, axis_idx)
			if child_axis.mode == SizeMode.Percent then
				self.engine:measure(child, axis_idx, true)
				s = s + child_axis.size + child_axis:getTotalMargin()
				child_count = child_count + 1
			end
		end
		s = s + layout_box.child_gap * math_max(0, child_count - 1)

		local constraint = max_s
		if node.parent then
			local parent_axis = self:getAxis(node.parent, axis_idx)
			if parent_axis.mode == SizeMode.Fixed or parent_axis.mode == SizeMode.Percent then
				local parent_constraint = parent_axis.size - parent_axis.padding_start - parent_axis.padding_end - axis.margin_start - axis.margin_end
				constraint = math.min(constraint, parent_constraint)
			end
		end

		if constraint < math.huge then
			local max_line_len = 0
			local current_line_len = 0
			for _, child in ipairs(node.children) do
				local child_axis = self:getAxis(child, axis_idx)
				local child_size = child_axis.size + child_axis:getTotalMargin()

				if current_line_len > 0 and current_line_len + layout_box.child_gap + child_size > constraint then
					max_line_len = math_max(max_line_len, current_line_len)
					current_line_len = child_size
				else
					if current_line_len > 0 then
						current_line_len = current_line_len + layout_box.child_gap
					end
					current_line_len = current_line_len + child_size
				end
			end
			max_line_len = math_max(max_line_len, current_line_len)
			s = max_line_len
		end

		s = axis.padding_start + s + axis.padding_end
		axis.size = math_clamp(s, min_s, max_s)
	else
		local main_axis_idx = (layout_box.arrange == Arrange.WrapRow) and Axis.X or Axis.Y
		local cross_axis_idx = axis_idx
		local main_axis = self:getAxis(node, main_axis_idx)

		local available_main = main_axis.size - main_axis.padding_start - main_axis.padding_end
		local total_cross = 0

		-- If main axis size is not yet determined (0 or negative available space),
		-- we can't do proper wrapping calculation. Assume all items fit on one line
		-- and use max child size for cross-axis.
		if available_main <= 0 then
			for _, child in ipairs(node.children) do
				local child_cross = self:getAxis(child, cross_axis_idx)
				if child_cross.mode ~= SizeMode.Percent then
					self.engine:measure(child, cross_axis_idx, parent_dirty_axis)
				end
				total_cross = math_max(total_cross, child_cross.size + child_cross:getTotalMargin())
			end
		else
			local current_main = 0
			local current_cross_max = 0
			local first_in_line = true

			for _, child in ipairs(node.children) do
				local child_main = self:getAxis(child, main_axis_idx)
				local child_cross = self:getAxis(child, cross_axis_idx)

				if child_cross.mode ~= SizeMode.Percent then
					self.engine:measure(child, cross_axis_idx, parent_dirty_axis)
				end

				local main_size = child_main.size + child_main:getTotalMargin()
				local cross_size = child_cross.size + child_cross:getTotalMargin()

				if not first_in_line and current_main + layout_box.child_gap + main_size > available_main then
					total_cross = total_cross + current_cross_max + layout_box.line_gap
					current_main = main_size
					current_cross_max = cross_size
				else
					if not first_in_line then
						current_main = current_main + layout_box.child_gap
					end
					current_main = current_main + main_size
					current_cross_max = math_max(current_cross_max, cross_size) ---@type number good old LLS bug
					first_in_line = false
				end
			end
			total_cross = total_cross + current_cross_max
		end

		local base_size = axis.padding_start + total_cross + axis.padding_end
		axis.size = math_clamp(base_size, min_s, max_s)

		for _, child in ipairs(node.children) do
			local child_cross = self:getAxis(child, cross_axis_idx)
			if child_cross.mode == SizeMode.Percent then
				self.engine:measure(child, cross_axis_idx, true)
			end
		end
	end
end

---@param dependency_dirty boolean?
function WrapStrategy:arrange(node, dependency_dirty)
	local layout_box = node.layout_box
	local parent_dirty = dependency_dirty or self.engine:isNodeDirty(node, Axis.Both)

	local main_axis_idx = (layout_box.arrange == Arrange.WrapRow) and Axis.X or Axis.Y
	local cross_axis_idx = (layout_box.arrange == Arrange.WrapRow) and Axis.Y or Axis.X

	local main_axis = self:getAxis(node, main_axis_idx)
	local cross_axis = self:getAxis(node, cross_axis_idx)

	local justify = layout_box.justify_content
	local align = layout_box.align_items

	local available_main = main_axis:getLayoutSize()
	local available_cross = cross_axis:getLayoutSize()
	local child_needs_arrange = {} ---@type {[ui.Node]: boolean}

	-- Resolve Percent sizing (was previously done in grow phase)
	for _, child in ipairs(node.children) do
		local needs_arrange = self.engine:needsArrange(child, parent_dirty)
		child_needs_arrange[child] = needs_arrange
		if needs_arrange then
			local child_main = self:getAxis(child, main_axis_idx)
			local child_cross = self:getAxis(child, cross_axis_idx)

			if child_main.mode == SizeMode.Percent then
				local s = child_main.preferred_size * (available_main - child_main:getTotalMargin())
				child_main.size = math_clamp(s, child_main.min_size, child_main.max_size)
			end
			if child_cross.mode == SizeMode.Percent then
				local s = child_cross.preferred_size * (available_cross - child_cross:getTotalMargin())
				child_cross.size = math_clamp(s, child_cross.min_size, child_cross.max_size)
			end

			-- Fit clamping on cross axis
			if child_cross.mode == SizeMode.Fit then
				local max_cross = available_cross - child_cross:getTotalMargin()
				if child_cross.size > max_cross and max_cross > 0 then
					child_cross.size = math_clamp(max_cross, child_cross.min_size, child_cross.max_size)
				end
			end
		end
	end

	local lines = {} ---@type {items: ui.Node[], main_size: number, raw_main_size: number, cross_size: number}[]
	local current_line = {items = {}, main_size = 0, raw_main_size = 0, cross_size = 0}

	for _, child in ipairs(node.children) do
		local child_main = self:getAxis(child, main_axis_idx)
		local child_cross = self:getAxis(child, cross_axis_idx)

		local item_main_size = child_main.size + child_main:getTotalMargin()
		local item_cross_size = child_cross.size + child_cross:getTotalMargin()

		if #current_line.items > 0 and current_line.main_size + layout_box.child_gap + item_main_size > available_main then
			table.insert(lines, current_line)
			current_line = {
				items = {child},
				main_size = item_main_size,
				raw_main_size = item_main_size,
				cross_size = item_cross_size,
			}
		else
			table.insert(current_line.items, child)
			if #current_line.items > 1 then
				current_line.main_size = current_line.main_size + layout_box.child_gap
			end
			current_line.main_size = current_line.main_size + item_main_size
			current_line.raw_main_size = current_line.raw_main_size + item_main_size
			current_line.cross_size = math_max(current_line.cross_size, item_cross_size)
		end
	end
	if #current_line.items > 0 then
		table.insert(lines, current_line)
	end

	local total_cross_size = 0
	for i, line in ipairs(lines) do
		total_cross_size = total_cross_size + line.cross_size
		if i > 1 then
			total_cross_size = total_cross_size + layout_box.line_gap ---@type number
		end
	end

	local cross_pos = cross_axis.padding_start
	if align == AlignItems.Center then
		cross_pos = cross_pos + (available_cross - total_cross_size) / 2
	elseif align == AlignItems.End then
		cross_pos = cross_pos + available_cross - total_cross_size
	end

	for _, line in ipairs(lines) do
		local main_pos = main_axis.padding_start
		local gap = layout_box.child_gap

		if justify == JustifyContent.End then
			main_pos = main_axis.padding_start + available_main - line.main_size
		elseif justify == JustifyContent.Center then
			main_pos = main_axis.padding_start + (available_main - line.main_size) / 2
		elseif justify == JustifyContent.SpaceBetween and #line.items > 1 then
			gap = (available_main - line.raw_main_size) / (#line.items - 1)
		end

		for _, child in ipairs(line.items) do
			local needs_arrange = child_needs_arrange[child]
			local child_main = self:getAxis(child, main_axis_idx)
			local child_cross = self:getAxis(child, cross_axis_idx)
			if needs_arrange then
				child_main.pos = main_pos + child_main.margin_start

				local child_align = child.layout_box.align_self or align
				local child_cross_pos = cross_pos + child_cross.margin_start

				if child_align == AlignItems.End then
					child_cross_pos = cross_pos + line.cross_size - child_cross.size - child_cross.margin_end
				elseif child_align == AlignItems.Center then
					child_cross_pos = cross_pos + (line.cross_size - child_cross.size - child_cross:getTotalMargin()) / 2 + child_cross.margin_start
				elseif child_align == AlignItems.Stretch then
					if child_cross.mode == SizeMode.Auto then
						child_cross.size = math_clamp(line.cross_size - child_cross:getTotalMargin(), child_cross.min_size, child_cross.max_size)
					end
					child_cross_pos = cross_pos + child_cross.margin_start
				end

				child_cross.pos = child_cross_pos

				self:arrangeChild(child, parent_dirty)
			end

			main_pos = main_pos + child_main.size + child_main:getTotalMargin() + gap
		end

		cross_pos = cross_pos + line.cross_size + layout_box.line_gap
	end
end

return WrapStrategy
