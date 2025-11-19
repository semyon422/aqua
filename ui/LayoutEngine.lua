local class = require("class")
local Node = require("ui.Node")
local Axis = Node.Axis
local SizeMode = Node.SizeMode
local Arrange = Node.Arrange
require("table.clear")

local math_min     = math.min
local math_max     = math.max
local bit_band     = bit.band

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field growables ui.Node[] Used in grow() to avoid creating a new table every time
local LayoutEngine = class()

---@param root ui.Node[]
function LayoutEngine:new(root)
	self.root = root
	self.growables = {}
end

---@param dirty_nodes ui.Node[]
---@return {[ui.Node]: boolean}? updated_layout_roots
function LayoutEngine:updateLayout(dirty_nodes)
	if #dirty_nodes == 0 then
		return
	end

	local layout_roots = {}

	for _, v in ipairs(dirty_nodes) do
		if v == self.root then
			layout_roots = {}
			layout_roots[self.root] = true
			break
		end

		local node = self:findLayoutBoundary(v, v.layout_axis_invalidated)
		layout_roots[node] = true
	end

	for node, _ in pairs(layout_roots) do
		local axis_flags = node.layout_axis_invalidated

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

---@param node ui.Node
---@param axis ui.Axis
--- Finds a node that can handle relayout
function LayoutEngine:findLayoutBoundary(node, axis)
	if not node.parent then
		return node
	end

	if self:isStableBoundary(node.parent, axis) then
		return node.parent
	end

	return self:findLayoutBoundary(node.parent, axis)
end

---@param node ui.Node
---@param axis ui.Axis
---@return boolean
--- Determines if a node has fixed dimensions for the requested axis, preventing layout shifts from bubbling up
function LayoutEngine:isStableBoundary(node, axis)
	if bit_band(node.layout_axis_invalidated, axis) ~= 0 then
		return true
	end

	local x_fixed = node.width_mode == SizeMode.Fixed
	local y_fixed = node.height_mode == SizeMode.Fixed

	if bit_band(axis, Axis.X) ~= 0 and not x_fixed then
		return false
	end
	if bit_band(axis, Axis.Y) ~= 0 and not y_fixed then
		return false
	end

	return true
end

---@param node ui.Node
function LayoutEngine:measureX(node)
	if node.width_mode == SizeMode.Fixed then
		for _, child in ipairs(node.children) do
			self:measureX(child)
		end
		return
	end

	local w = 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:measureX(child)
			w = math_max(w, child.x + child.width)
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			self:measureX(child)
			w = math_max(w, child.width)
		end
	elseif node.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			self:measureX(child)
			w = w + child.width
		end

		w = w + node.child_gap * (math_max(0, #node.children - 1))
	end

	node.width = node.padding_left + w + node.padding_right
end

---@param node ui.Node
function LayoutEngine:measureY(node)
	if node.height_mode == SizeMode.Fixed then
		for _, child in ipairs(node.children) do
			self:measureY(child)
		end
		return
	end

	local h = 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:measureY(child)
			h = math_max(h, child.y + child.height)
		end
	elseif node.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			self:measureY(child)
			h = math_max(h, child.height)
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			self:measureY(child)
			h = h + child.height
		end

		h = h + (node.child_gap * (math_max(0, #node.children - 1)))
	end

	node.height = node.padding_top + h + node.padding_bottom
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

---@param node ui.Node
---@param axis ui.Axis
function LayoutEngine:grow(node, axis)
	if #node.children == 0 then
		return
	end

	local props = grow_props[axis]

	table.clear(self.growables)
	local available_space = node[props.size] - node[props.padding_start] - node[props.padding_end]

	for _, child in ipairs(node.children) do
		if child[props.mode] == SizeMode.Grow then
			table.insert(self.growables, child)
		elseif node.arrange == props.flow then
			available_space = available_space - child[props.size]
		end
	end

	if node.arrange == props.flow then
		available_space = available_space - (node.child_gap * math_max(0, #node.children - 1))
	end

	if #self.growables > 0 then
		if node.arrange == props.flow then
			self:distributeSpaceEvenly(self.growables, available_space, props.size)
		elseif node.arrange == Arrange.Absolute then
			for _, child in ipairs(self.growables) do
				child[props.size] = available_space
			end
		else
			for _, child in ipairs(self.growables) do
				child[props.size] = available_space
			end
		end
	end

	for _, child in ipairs(node.children) do
		self:grow(child, axis)
	end
end

---@param children ui.Node[]
---@param available_space number
---@param size_prop string
function LayoutEngine:distributeSpaceEvenly(children, available_space, size_prop)
	while available_space > 0 do
		local smallest = math.huge
		local second_smallest = math.huge

		for _, child in ipairs(children) do
			local size = child[size_prop]
			if size < smallest then
				second_smallest = smallest
				smallest = size
			elseif size > smallest and size < second_smallest then
				second_smallest = size
			end
		end

		local size_to_add = math_min(second_smallest - smallest, available_space / #children)

		for _, child in ipairs(children) do
			if child[size_prop] == smallest then
				child[size_prop] = child[size_prop] + size_to_add
				available_space = available_space - size_to_add
			end
		end
	end
end

---@param node ui.Node
function LayoutEngine:arrangeChildren(node)
	local x, y = 0, 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:arrangeChildren(child)
		end
	elseif node.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			child.x = x
			child.y = y
			self:arrangeChildren(child)
			x = x + child.width + node.child_gap
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			child.x = x
			child.y = y
			self:arrangeChildren(child)
			y = y + child.height + node.child_gap
		end
	end
end

return LayoutEngine
