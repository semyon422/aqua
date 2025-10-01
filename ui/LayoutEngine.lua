local class = require("class")
local Node = require("ui.Node")
local Axis = Node.Axis
local SizeMode = Node.SizeMode
local Arrange = Node.Arrange

---@class ui.LayoutEngine
---@operator call: ui.LayoutEngine
local LayoutEngine = class()

---@param root ui.Node[]
function LayoutEngine:new(root)
	self.root = root
end

---@param nodes ui.Node[]
function LayoutEngine:updateLayout(nodes)
	local suitable_nodes = {}

	for _, v in ipairs(nodes) do
		local node = self:findLayoutResolver(v, v.invalidate_axis)
		suitable_nodes[node] = true

		if node == self.root then
			suitable_nodes = {}
			suitable_nodes[self.root] = true
			break
		end
	end

	for node, _ in pairs(suitable_nodes) do
		local axis = node.invalidate_axis

		if bit.band(axis, Axis.X) then
			self:fitX(node)
			self:growX(node)
		end
		if bit.band(axis, Axis.Y) then
			self:fitY(node)
			self:growY(node)
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
	elseif self.arrange == Arrange.FlowH then
		for _, child in ipairs(self.children) do
			child:fitY(child)
			h = math.max(h, child.height)
		end
	elseif self.arrange == Arrange.FlowV then
		for _, child in ipairs(self.children) do
			child:fitY(child)
			h = h + child.height
		end
		h = h + (self.child_gap * (math.max(0, #self.children - 1)))
	end

	self.height = self.padding_top + h + self.padding_bottom
end

function LayoutEngine:growX(node)
	local remaining_width = node.width
	remaining_width = remaining_width - node.padding_left - node.padding_right

	if node.arrange == Arrange.FlowH then
		remaining_width = remaining_width - (node.child_gap * (math.max(0, #node.children - 1)))
	end

	for _, child in ipairs(node.children) do
		if child.width_mode ~= SizeMode.Grow then
			remaining_width = remaining_width - child.width
		end
	end

	for _, child in ipairs(node.children) do
		if child.width_mode == SizeMode.Grow then
			child.width = remaining_width
		end
		self:growX(child)
	end
end

function LayoutEngine:growY(node)
	local remaining_height = node.height
	remaining_height = remaining_height - node.padding_top - node.padding_bottom

	if node.arrange == Arrange.FlowV then
		remaining_height = remaining_height - (node.child_gap * (math.max(0, #node.children - 1)))
	end

	for _, child in ipairs(node.children) do
		if child.height_mode ~= SizeMode.Grow then
			remaining_height = remaining_height - child.height
		end
	end

	for _, child in ipairs(node.children) do
		if child.height_mode == SizeMode.Grow then
			child.height = remaining_height
		end
		self:growY(child)
	end
end

function LayoutEngine:positionChildren(node)
	local x, y = 0, 0

	if node.arrange == Arrange.Absolute then
		for _, child in ipairs(node.children) do
			self:updateTransform(child)
			self:positionChildren(child)
		end
	elseif self.arrange == Arrange.FlowH then
		for _, child in ipairs(node.children) do
			child:setPosition(x, y)
			self:updateTransform(child)
			self:positionChildren(child)
			x = x + child:getWidth() + node.child_gap
		end
	elseif node.arrange == Arrange.FlowV then
		for _, child in ipairs(node.children) do
			child:setPosition(x, y)
			self:updateTransform(child)
			self:positionChildren(child)
			y = y + child:getHeight() + node.child_gap
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
		-- But it would have been better if there was Transform:apply(other, reverse)
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
end

return LayoutEngine
