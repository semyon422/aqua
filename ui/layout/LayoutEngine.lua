local class = require("class")
local table_util = require("table_util")
local math_util = require("math_util")
local Enums = require("ui.layout.Enums")
local Axis = Enums.Axis
local SizeMode = Enums.SizeMode
local Arrange = Enums.Arrange
local JustifyContent = Enums.JustifyContent
local AlignItems = Enums.AlignItems

local math_min = math.min
local math_max = math.max
local math_clamp = math_util.clamp
local bit_band = bit.band

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field growables ui.INode[] Used in grow() to avoid creating a new table every time
---@field active_children ui.INode[] Used in distributeFlexSpace for the same reason
---@field next_active_children ui.INode[] Used in distributeFlexSpace for the same reason
local LayoutEngine = class()

function LayoutEngine:new()
	self.growables = {}
	self.active_children = {}
	self.next_active_children = {}
end

local frame = 0

---@param dirty_nodes ui.INode[]
---@return {[ui.INode]: boolean}? updated_layout_roots
function LayoutEngine:updateLayout(dirty_nodes)
	frame = frame + 1

	if #dirty_nodes == 0 then
		return
	end

	local s = love.timer.getTime()

	---@type {[ui.INode]: boolean}
	local layout_roots = {}

	for _, v in ipairs(dirty_nodes) do
		local node = self:findLayoutBoundary(v, v.layout_box.axis_invalidated)
		layout_roots[node] = true

		if not node.parent then -- Reached the root
			layout_roots = {}
			layout_roots[node] = true
			break
		end
	end

	for node, _ in pairs(layout_roots) do
		local axis_flags = node.layout_box.axis_invalidated

		if bit_band(axis_flags, Axis.X) then
			self:measure(node, Axis.X)
			self:grow(node, Axis.X)
		end

		if bit_band(axis_flags, Axis.Y) then
			self:measure(node, Axis.Y)
			self:grow(node, Axis.Y)
		end

		local target = node.parent and node.parent or node
		self:arrangeChildren(target)
	end

	print(("[LAYOUT] frame: %i took: %0.02f MS"):format(frame, (love.timer.getTime() - s) * 1000))

	return layout_roots
end

---@param node ui.INode
---@param axis ui.Axis
--- Finds a node that can handle relayout
function LayoutEngine:findLayoutBoundary(node, axis)
	if not node.parent then
		return node
	end

	if self:isStableBoundary(node.parent.layout_box, axis) then
		return node.parent
	end

	return self:findLayoutBoundary(node.parent, axis)
end

---@param layout_box ui.LayoutBox
---@param axis ui.Axis
---@return boolean
--- Determines if a node has fixed dimensions for the requested axis, preventing layout shifts from bubbling up
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

---@param node ui.INode
---@param axis_idx ui.Axis
---@return ui.LayoutAxis
local function getAxisFrom(node, axis_idx)
	return (axis_idx == Axis.X) and node.layout_box.x or node.layout_box.y
end

---@param layout_box ui.LayoutBox
---@param axis_idx ui.Axis
---@return boolean
local function isMainAxis(layout_box, axis_idx)
	return (
		(layout_box.arrange == Arrange.FlowH and axis_idx == Axis.X) or
		(layout_box.arrange == Arrange.FlowV and axis_idx == Axis.Y)
	)
end

---@param node ui.INode
---@param axis_idx ui.Axis
function LayoutEngine:measure(node, axis_idx)
	local layout_box = node.layout_box
	local axis = getAxisFrom(node, axis_idx)
	local min_s = axis.min_size
	local max_s = axis.max_size

	if axis.mode == SizeMode.Fixed or axis.mode == SizeMode.Percent then
		local s = axis.preferred_size
		if axis.mode == SizeMode.Percent then
			local parent_size = 0
			if node.parent then
				local parent_axis = getAxisFrom(node.parent, axis_idx)
				parent_size = parent_axis:getLayoutSize()
			end
			s = s * parent_size
		end

		axis.size = math_clamp(s, min_s, max_s)
		for _, child in ipairs(node.children) do
			if not child.is_disabled then
				self:measure(child, axis_idx)
			end
		end
		return
	end

	local s = 0.0

	if layout_box.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			if not child.is_disabled then
				self:measure(child, axis_idx)
				local child_axis = getAxisFrom(child, axis_idx)
				s = math_max(s, child_axis.pos + child_axis.size)
			end
		end
	else
		local is_main_axis = isMainAxis(layout_box, axis_idx)
		local child_count = 0

		if is_main_axis then
			for _, child in ipairs(node.children) do
				if not child.is_disabled then
					self:measure(child, axis_idx)
					local child_axis = getAxisFrom(child, axis_idx)
					s = s + child_axis.size
					child_count = child_count + 1
				end
			end
			s = s + layout_box.child_gap * (math_max(0, child_count - 1))
		else
			for _, child in ipairs(node.children) do
				if not child.is_disabled then
					self:measure(child, axis_idx)
					local child_axis = getAxisFrom(child, axis_idx)
					s = math_max(s, child_axis.size)
				end
			end
		end
	end

	s = axis.padding_start + s + axis.padding_end
	axis.size = math_clamp(s, min_s, max_s)
end

---@param node ui.INode
---@param axis_idx ui.Axis
function LayoutEngine:grow(node, axis_idx)
	if #node.children == 0 then
		return
	end

	local layout_box = node.layout_box
	local flow = axis_idx == Axis.X and Arrange.FlowH or Arrange.FlowV
	local axis = layout_box:getAxis(axis_idx)

	table_util.clear(self.growables)
	local available_space = axis:getLayoutSize()
	local total_grow = 0
	local child_count = 0

	local is_main_axis = layout_box.arrange == flow
	local is_cross_axis = layout_box.arrange ~= Arrange.Absolute and not is_main_axis

	for _, child in ipairs(node.children) do
		if child.is_disabled then
			goto continue
		end

		local child_axis = child.layout_box:getAxis(axis_idx)
		child_count = child_count + 1

		if child_axis.mode == SizeMode.Percent then
			local parent_size = axis:getLayoutSize()
			local s = child_axis.preferred_size * parent_size
			child_axis.size = math_clamp(s, child_axis.min_size, child_axis.max_size)
		end

		if is_main_axis then
			available_space = available_space - child_axis.size

			if child.layout_box.grow > 0 then
				table.insert(self.growables, child)
				total_grow = total_grow + child.layout_box.grow
			end
		elseif is_cross_axis then
			local align = child.layout_box.align_self or layout_box.align_items
			if align == AlignItems.Stretch then
				-- Only Auto can stretch
				if child_axis.mode == SizeMode.Auto then
					table.insert(self.growables, child)
				end
			end
		else
			-- Absolute
			-- Will inherit the size of the parent
			if child.layout_box.grow > 0 and child_axis.mode == SizeMode.Auto then
				table.insert(self.growables, child)
				total_grow = total_grow + child.layout_box.grow
			end
		end

		::continue::
	end

	if is_main_axis then
		available_space = available_space - (layout_box.child_gap * math_max(0, child_count - 1))
	end

	if #self.growables > 0 and available_space > 0 then
		if is_main_axis then
			self:distributeFlexSpace(self.growables, available_space, total_grow, axis_idx)
		elseif is_cross_axis then
			-- Stretch logic
			for _, child in ipairs(self.growables) do
				local child_axis = child.layout_box:getAxis(axis_idx)
				local new_size = math_clamp(available_space, child_axis.min_size, child_axis.max_size)
				child_axis.size = new_size
			end
		elseif layout_box.arrange == Arrange.Absolute then
			-- Absolute grow logic
			for _, child in ipairs(self.growables) do
				local child_axis = child.layout_box:getAxis(axis_idx)
				local new_size = math_clamp(available_space, child_axis.min_size, child_axis.max_size)
				child_axis.size = new_size
			end
		end
	end

	for _, child in ipairs(node.children) do
		if not child.is_disabled then
			self:grow(child, axis_idx)
		end
	end
end

---@param children ui.INode[]
---@param available_space number
---@param total_grow number
---@param axis_idx ui.Axis
function LayoutEngine:distributeFlexSpace(children, available_space, total_grow, axis_idx)
	local remaining_space = available_space
	local current_total_grow = total_grow

	local active = self.active_children
	local next_active = self.next_active_children

	table_util.clear(active)
	for i = 1, #children do
		active[i] = children[i]
	end

	while #active > 0 and remaining_space > 0 and current_total_grow > 0 do
		table_util.clear(next_active)
		local next_total_grow = 0
		local any_capped = false
		local space_to_distribute = remaining_space

		for _, child in ipairs(active) do
			local child_axis = child.layout_box:getAxis(axis_idx)
			local grow_factor = child.layout_box.grow / current_total_grow
			local add_size = space_to_distribute * grow_factor
			local target_size = child_axis.size + add_size

			if target_size > child_axis.max_size then
				local actually_added = child_axis.max_size - child_axis.size
				child_axis.size = child_axis.max_size
				remaining_space = remaining_space - actually_added
				any_capped = true
			else
				next_active[#next_active + 1] = child
				next_total_grow = next_total_grow + child.layout_box.grow
			end
		end

		if not any_capped then
			for _, child in ipairs(active) do
				local child_axis = child.layout_box:getAxis(axis_idx)
				local grow_factor = child.layout_box.grow / current_total_grow
				child_axis.size = child_axis.size + remaining_space * grow_factor
			end
			remaining_space = 0
			break
		end

		next_active, active = active, next_active
		current_total_grow = next_total_grow
	end
end

---@param node ui.INode
function LayoutEngine:arrangeChildren(node)
	local layout_box = node.layout_box

	if layout_box.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			if not child.is_disabled then
				self:arrangeChildren(child)
			end
		end
		return
	end

	local main_axis_idx = (layout_box.arrange == Arrange.FlowH) and Axis.X or Axis.Y
	local cross_axis_idx = (layout_box.arrange == Arrange.FlowH) and Axis.Y or Axis.X

	local main_axis = layout_box:getAxis(main_axis_idx)
	local cross_axis = layout_box:getAxis(cross_axis_idx)

	local justify = layout_box.justify_content
	local align = layout_box.align_items

	local child_count = 0
	for _, child in ipairs(node.children) do
		if not child.is_disabled then
			child_count = child_count + 1
		end
	end

	-- Calculate total size on main axis (excluding disabled children)
	local total_main_size = 0
	for _, child in ipairs(node.children) do
		if not child.is_disabled then
			total_main_size = total_main_size + child.layout_box:getAxis(main_axis_idx).size
		end
	end

	local available_main = main_axis:getLayoutSize()
	local available_cross = cross_axis:getLayoutSize()

	local pos = 0
	local gap = layout_box.child_gap

	--- LLS bug
	---@cast total_main_size number

	if justify == JustifyContent.End then
		pos = available_main - (total_main_size + gap * (child_count - 1))
	elseif justify == JustifyContent.Center then
		pos = (available_main - (total_main_size + gap * (child_count - 1))) / 2
	elseif justify == JustifyContent.SpaceBetween and child_count > 1 then
		gap = (available_main - total_main_size) / (child_count - 1)
		pos = 0
	end

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

		if child.is_disabled then
			goto continue
		end

		local child_main = child.layout_box:getAxis(main_axis_idx)
		local child_cross = child.layout_box:getAxis(cross_axis_idx)

		-- Position on main axis
		child_main.pos = pos

		-- Position on cross axis
		local child_align = child.layout_box.align_self or align
		local cross_pos = 0

		if child_align == AlignItems.End then
			cross_pos = available_cross - child_cross.size
		elseif child_align == AlignItems.Center then
			cross_pos = (available_cross - child_cross.size) / 2
		end

		child_cross.pos = cross_pos

		self:arrangeChildren(child)
		pos = pos + child_main.size + gap

		::continue::
	end
end

return LayoutEngine
