local class = require("class")
local Node = require("ui.Node")
local Axis = Node.Axis
local SizeMode = Node.SizeMode
local Arrange = Node.Arrange
require("table.clear")

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
---@field growables ui.Node[] Used in grow() to avoid creating a new table every time
local LayoutEngine = class()

---@param root ui.Node[]
function LayoutEngine:new(root)
	self.root = root
	self.growables = {}
end

---@param nodes ui.Node[]
function LayoutEngine:updateLayout(nodes)
	local suitable_nodes = {}

	for _, v in ipairs(nodes) do
		if v == self.root then
			suitable_nodes = {}
			suitable_nodes[self.root] = true
			break
		end

		local node = self:findLayoutResolver(v, v.invalidate_axis)
		suitable_nodes[node] = true
	end

	for node, _ in pairs(suitable_nodes) do
		local axis = node.invalidate_axis

		if bit.band(axis, Axis.X) then
			self:fitX(node)
			self:grow(node, Axis.X)
		end
		if bit.band(axis, Axis.Y) then
			self:fitY(node)
			self:grow(node, Axis.Y)
		end

		if node.parent then
			self:positionChildren(node.parent)
		else
			self:updateTransform(node)
			self:positionChildren(node)
		end

		node.invalidate_axis = Axis.None
	end
end

---@param node ui.Node
---@param axis ui.Axis
--- Finds a suitable node that can handle relayout
function LayoutEngine:findLayoutResolver(node, axis)
	if not node.parent then
		return node
	end

	if self:canResolveLayout(node.parent, axis) then
		return node.parent
	else
		return self:findLayoutResolver(node.parent, axis)
	end
end

---@param node ui.Node
---@param axis ui.Axis
---@return boolean
--- It's safe to use nodes that have fixed width/height for layout recalculation without going to the root and recalculating the whole thing from scratch
function LayoutEngine:canResolveLayout(node, axis)
	if bit.band(node.invalidate_axis, axis) ~= 0 then
		return true
	end

	local x_fixed = node.width_mode == SizeMode.Fixed
	local y_fixed = node.height_mode == SizeMode.Fixed

	if bit.band(axis, Axis.X) ~= 0 and not x_fixed then
		return false
	end
	if bit.band(axis, Axis.Y) ~= 0 and not y_fixed then
		return false
	end

	return true
end

---@param node ui.Node
function LayoutEngine:fitX(node)
	if node.width_mode == SizeMode.Fixed then
		for _, child in ipairs(node.children) do
			self:fitX(child)
		end
		return
	end

	local w = 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:fitX(child)
			w = math.max(w, child.x + child.width)
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			self:fitX(child)
			w = math.max(w, child.width)
		end
	elseif node.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			self:fitX(child)
			w = w + child.width
		end

		w = w + node.child_gap * (math.max(0, #node.children - 1))
	end

	node.width = node.padding_left + w + node.padding_right
end

---@param node ui.Node
function LayoutEngine:fitY(node)
	if node.height_mode == SizeMode.Fixed then
		for _, child in ipairs(node.children) do
			self:fitY(child)
		end
		return
	end

	local h = 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:fitY(child)
			h = math.max(h, child.y + child.height)
		end
	elseif node.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			self:fitY(child)
			h = math.max(h, child.height)
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			self:fitY(child)
			h = h + child.height
		end

		h = h + (node.child_gap * (math.max(0, #node.children - 1)))
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
		available_space = available_space - (node.child_gap * math.max(0, #node.children - 1))
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

		local size_to_add = math.min(second_smallest - smallest, available_space / #children)

		for _, child in ipairs(children) do
			if child[size_prop] == smallest then
				child[size_prop] = child[size_prop] + size_to_add
				available_space = available_space - size_to_add
			end
		end
	end
end

---@param node ui.Node
function LayoutEngine:positionChildren(node)
	local x, y = 0, 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:updateTransform(child)
			self:positionChildren(child)
		end
	elseif node.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			child:setPosition(x, y)
			self:updateTransform(child)
			self:positionChildren(child)
			x = x + child.width + node.child_gap
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			child:setPosition(x, y)
			self:updateTransform(child)
			self:positionChildren(child)
			y = y + child.height + node.child_gap
		end
	end
end

local tf = love.math.newTransform()

function LayoutEngine:updateTransform(node)
	local x, y = 0, 0

	if node.parent then
		x = node.x + node.anchor.x * node.parent:getLayoutWidth() + node.parent.padding_left
		y = node.y + node.anchor.y * node.parent:getLayoutHeight() + node.parent.padding_top
	else
		x = node.x
		y = node.y
	end

	if node.parent then
		-- The code below doesn't create a new transform, that's good
		-- But it would have been better if there was Transform:apply(other, reverse_order)
		node.transform:reset()
		node.transform:apply(node.parent.transform)
		tf:setTransformation(
			x,
			y,
			node.angle,
			node.scale_x,
			node.scale_y,
			node.origin.x * node.width,
			node.origin.y * node.height
		)
		node.transform:apply(tf)
	else
		node.transform:setTransformation(
			x,
			y,
			node.angle,
			node.scale_x,
			node.scale_y,
			node.origin.x * node.width,
			node.origin.y * node.height
		)
	end

	node.invalidate_axis = Axis.None
	node:dimensionsChanged()
end

return LayoutEngine
