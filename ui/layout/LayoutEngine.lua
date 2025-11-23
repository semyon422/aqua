local class = require("class")
local LayoutBox = require("ui.layout.LayoutBox")
local Axis = LayoutBox.Axis
local SizeMode = LayoutBox.SizeMode
local Arrange = LayoutBox.Arrange
local JustifyContent = LayoutBox.JustifyContent
local AlignItems = LayoutBox.AlignItems
require("table.clear")

local math_min = math.min
local math_max = math.max
local bit_band = bit.band

---@class ui.LayoutEngine.Node : ui.INode, ui.HasLayoutBox
---@field parent ui.LayoutEngine.Node?
---@field children ui.LayoutEngine.Node[]

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field growables ui.LayoutEngine.Node[] Used in grow() to avoid creating a new table every time
local LayoutEngine = class()

function LayoutEngine:new()
	self.growables = {}
end

---@param dirty_nodes ui.LayoutEngine.Node[]
---@return {[ui.LayoutEngine.Node]: boolean}? updated_layout_roots
function LayoutEngine:updateLayout(dirty_nodes)
	if #dirty_nodes == 0 then
		return
	end

	---@type {[ui.LayoutEngine.Node]: boolean}
	local layout_roots = {}

	for _, v in ipairs(dirty_nodes) do
		if not v.parent then -- Reached the root
			layout_roots = {}
			layout_roots[v] = true
			break
		end

		local node = self:findLayoutBoundary(v, v.layout_box.axis_invalidated)
		layout_roots[node] = true
	end

	for node, _ in pairs(layout_roots) do
		local axis_flags = node.layout_box.axis_invalidated

		if bit_band(axis_flags, Axis.X) then
			self:measureX(node)
			self:grow(node, Axis.X)
		end

		if bit_band(axis_flags, Axis.Y) then
			self:measureY(node)
			self:grow(node, Axis.Y)
		end

		local target = node.parent and node.parent or node
		self:arrangeChildren(target)
	end

	return layout_roots
end

---@param node ui.LayoutEngine.Node
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

	local x_fixed = layout_box.width_mode == SizeMode.Fixed
	local y_fixed = layout_box.height_mode == SizeMode.Fixed

	if bit_band(axis, Axis.X) ~= 0 and not x_fixed then
		return false
	end
	if bit_band(axis, Axis.Y) ~= 0 and not y_fixed then
		return false
	end

	return true
end

---@param node ui.LayoutEngine.Node
function LayoutEngine:measureX(node)
	local layout_box = node.layout_box

	if layout_box.width_mode == SizeMode.Fixed then
		for _, child in ipairs(node.children) do
			self:measureX(child)
		end
		return
	end

	local w = 0

	if layout_box.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:measureX(child)
			w = math_max(w, child.layout_box.x + child.layout_box.width)
		end
	elseif layout_box.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			self:measureX(child)
			w = math_max(w, child.layout_box.width)
		end
	elseif layout_box.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			self:measureX(child)
			w = w + child.layout_box.width
		end

		w = w + layout_box.child_gap * (math_max(0, #node.children - 1))
	end

	layout_box.width = layout_box.padding_left + w + layout_box.padding_right
end

---@param node ui.LayoutEngine.Node
function LayoutEngine:measureY(node)
	local layout_box = node.layout_box

	if layout_box.height_mode == SizeMode.Fixed then
		for _, child in ipairs(node.children) do
			self:measureY(child)
		end
		return
	end

	local h = 0

	if layout_box.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:measureY(child)
			h = math_max(h, child.layout_box.y + child.layout_box.height)
		end
	elseif layout_box.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			self:measureY(child)
			h = math_max(h, child.layout_box.height)
		end
	elseif layout_box.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			self:measureY(child)
			h = h + child.layout_box.height
		end

		h = h + (layout_box.child_gap * (math_max(0, #node.children - 1)))
	end

	layout_box.height = layout_box.padding_top + h + layout_box.padding_bottom
end

local grow_props = {
	[Axis.X] = {
		size = "width",
		mode = "width_mode",
		padding_start = "padding_left",
		padding_end = "padding_right",
		flow = Arrange.FlowH
	},
	[Axis.Y] = {
		size = "height",
		mode = "height_mode",
		padding_start = "padding_top",
		padding_end = "padding_bottom",
		flow = Arrange.FlowV
	}
}

---@param node ui.LayoutEngine.Node
---@param axis ui.Axis
function LayoutEngine:grow(node, axis)
	if #node.children == 0 then
		return
	end

	local layout_box = node.layout_box
	local props = grow_props[axis]

	table.clear(self.growables)
	local available_space = layout_box[props.size] - layout_box[props.padding_start] - layout_box[props.padding_end]

	for _, child in ipairs(node.children) do
		if child.layout_box[props.mode] == SizeMode.Grow then
			table.insert(self.growables, child)
		elseif layout_box.arrange == props.flow then
			available_space = available_space - child.layout_box[props.size]
		end
	end

	if layout_box.arrange == props.flow then
		available_space = available_space - (layout_box.child_gap * math_max(0, #node.children - 1))
	end

	if #self.growables > 0 then
		if layout_box.arrange == props.flow then
			self:distributeSpaceEvenly(self.growables, available_space, props.size)
		elseif layout_box.arrange == Arrange.Absolute then
			for _, child in ipairs(self.growables) do
				child.layout_box[props.size] = available_space
			end
		else
			for _, child in ipairs(self.growables) do
				child.layout_box[props.size] = available_space
			end
		end
	end

	for _, child in ipairs(node.children) do
		self:grow(child, axis)
	end
end

---@param children ui.LayoutEngine.Node[]
---@param available_space number
---@param size_prop string
function LayoutEngine:distributeSpaceEvenly(children, available_space, size_prop)
	while available_space > 0 do
		local smallest = math.huge
		local second_smallest = math.huge

		for _, child in ipairs(children) do
			local size = child.layout_box[size_prop]
			if size < smallest then
				second_smallest = smallest
				smallest = size
			elseif size > smallest and size < second_smallest then
				second_smallest = size
			end
		end

		local size_to_add = math_min(second_smallest - smallest, available_space / #children)

		for _, child in ipairs(children) do
			if child.layout_box[size_prop] == smallest then
				child.layout_box[size_prop] = child.layout_box[size_prop] + size_to_add
				available_space = available_space - size_to_add
			end
		end
	end
end

---@param node ui.LayoutEngine.Node
function LayoutEngine:arrangeChildren(node)
	local layout_box = node.layout_box
	local justify = layout_box.justify_content
	local align = layout_box.align_items
	local child_count = #node.children

	if layout_box.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:arrangeChildren(child)
		end
	elseif layout_box.arrange == Arrange.FlowH then
		local total_width = 0
		for _, child in ipairs(node.children) do
			total_width = total_width + child.layout_box.width
		end

		local available_width = layout_box:getLayoutWidth()
		local x = 0
		local gap = layout_box.child_gap

		if justify == JustifyContent.End then
			x = available_width - (total_width + gap * (child_count - 1))
		elseif justify == JustifyContent.Center then
			x = (available_width - (total_width + gap * (child_count - 1))) / 2
		elseif justify == JustifyContent.SpaceBetween and child_count > 1 then
			gap = (available_width - total_width) / (child_count - 1)
			x = 0
		end

		for _, child in ipairs(node.children) do
			local child_y = 0
			local available_height = layout_box:getLayoutHeight()

			if align == AlignItems.End then
				child_y = available_height - child.layout_box.height
			elseif align == AlignItems.Center then
				child_y = (available_height - child.layout_box.height) / 2
			end

			child.layout_box.x = x
			child.layout_box.y = child_y
			self:arrangeChildren(child)
			x = x + child.layout_box.width + gap
		end
	elseif layout_box.arrange == Arrange.FlowV then
		local total_height = 0
		for _, child in ipairs(node.children) do
			total_height = total_height + child.layout_box.height
		end

		local available_height = layout_box:getLayoutHeight()
		local y = 0
		local gap = layout_box.child_gap

		if justify == JustifyContent.End then
			y = available_height - (total_height + gap * (child_count - 1))
		elseif justify == JustifyContent.Center then
			y = (available_height - (total_height + gap * (child_count - 1))) / 2
		elseif justify == JustifyContent.SpaceBetween and child_count > 1 then
			gap = (available_height - total_height) / (child_count - 1)
			y = 0
		end

		for _, child in ipairs(node.children) do
			local child_x = 0
			local available_width = layout_box:getLayoutWidth()

			if align == AlignItems.End then
				child_x = available_width - child.layout_box.width
			elseif align == AlignItems.Center then
				child_x = (available_width - child.layout_box.width) / 2
			end

			child.layout_box.x = child_x
			child.layout_box.y = y
			self:arrangeChildren(child)
			y = y + child.layout_box.height + gap
		end
	end
end

return LayoutEngine
