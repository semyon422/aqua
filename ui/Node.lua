local class = require("class")
local NodeTransform = require("ui.NodeTransform")

---@class ui.Pivot
---@field x number
---@field y number

---@alias ui.Color [number, number, number, number]

---@class ui.Node
---@operator call: ui.Node
---@field id string?
---@field parent ui.Node?
---@field children ui.Node[]
---@field context ui.Context
---@field draw? fun(self: ui.Node)
---@field style ui.Style?
--- Position can be changed only if the node is inside a container with Absolute arrange.
--- Use `node.transform` for translating inside containers with `Flow`.
---@field x number
---@field y number
--- Dimensions can be changed only if the size mode is `Fixed`.
---@field width number
---@field height number
local Node = class()

Node.ClassName = "Node"

Node.State = {
	Created = 1,
	Loaded = 2,
	Ready = 3,
	Killed = 4,
}

Node.Pivot = {
	TopLeft = { x = 0, y = 0 },
	TopCenter = { x = 0.5, y = 0 },
	TopRight = { x = 1, y = 0 },
	CenterLeft = { x = 0, y = 0.5 },
	Center = { x = 0.5, y = 0.5 },
	CenterRight = { x = 1, y = 0.5 },
	BottomLeft = { x = 0, y = 1 },
	BottomCenter = { x = 0.5, y = 1 },
	BottomRight = { x = 1, y = 1 },
}

---@enum ui.SizeMode
Node.SizeMode = {
	Fixed = 1,
	Fit = 2,
	Grow = 3,
}

---@enum ui.Arrange
Node.Arrange = {
	Absolute = 1,
	FlowH = 2,
	FlowV = 3,
}

---@enum ui.Axis
Node.Axis = {
	None = 0,
	X = 1,
	Y = 2,
	Both = 3,
}

local Pivot = Node.Pivot
local SizeMode = Node.SizeMode
local Arrange = Node.Arrange
local Axis = Node.Axis
local State = Node.State

Node.TransformParams = function(node, params)
	for k, v in pairs(params) do
		node[k] = v
	end
end

---@param params {[string]: any}?
function Node:new(params)
	self.z = 0
	self.transform = NodeTransform()

	-- TODO:  Move to NodeLayout class ???
	self.x = 0
	self.y = 0
	self.width = 0
	self.height = 0
	self.origin = Pivot.TopLeft
	self.anchor = Pivot.TopLeft
	self.width_mode = SizeMode.Fixed
	self.height_mode = SizeMode.Fixed
	self.padding_left = 0
	self.padding_right = 0
	self.padding_top = 0
	self.padding_bottom = 0
	self.child_gap = 0
	self.arrange = Arrange.Absolute
	self.layout_axis_invalidated = Axis.None

	self.mouse_over = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self.is_disabled = false
	self.children = {}
	self.state = State.Created

	if params then
		Node.TransformParams(self, params)
	end

	if self.style then
		assert(getmetatable(self.style), "Style class expected, got a regular table instead.")
		self.style:setDimensions(self.width, self.height)
	end
end

function Node:load() end

--- Will be called once right before the update method after the node was loaded
function Node:loadComplete() end

---@param dt number
function Node:update(dt) end

---@generic T : ui.Node
---@param node T
---@return T
function Node:add(node)
	---@cast node ui.Node
	local inserted = false

	if #self.children ~= 0 then
		for i, child in ipairs(self.children) do
			if node.z < child.z then
				table.insert(self.children, i, node)
				inserted = true
				break
			end
		end
	end

	if not inserted then
		table.insert(self.children, node)
	end

	node.parent = self
	node.context = self.context
	node:load()
	node.state = State.Loaded

	return node
end

---@param mouse_x number
---@param mouse_y number
---@param imx number
---@param imy number
function Node:isMouseOver(mouse_x, mouse_y, imx, imy)
	return imx >= 0 and imx < self.width and imy >= 0 and imy < self.height
end

---@param node ui.Node
function Node:remove(node)
	for i, child in ipairs(self.children) do
		if child == node then
			table.remove(self.children, i)
			return
		end
	end
end

function Node:kill()
	self.state = State.Killed
end

--- Sets layout X, layout Y and origins with anchors in the ui.Transform
function Node:updateTreeLayout()
	local x, y = 0, 0
	local parent_tf ---@type love.Transform?

	if self.parent then
		x = self.x + self.anchor.x * self.parent:getLayoutWidth() + self.parent.padding_left
		y = self.y + self.anchor.y * self.parent:getLayoutHeight() + self.parent.padding_top
		parent_tf = self.parent.transform:get()
	else
		x = self.x
		y = self.y
	end

	local origin_x = self.origin.x * self.width
	local origin_y = self.origin.y * self.height

	self.transform:setLayout(parent_tf, x, y, origin_x, origin_y)

	if self.style then
		self.style:setDimensions(self.width, self.height)
	end

	self.layout_axis_invalidated = Axis.None

	for _, child in ipairs(self.children) do
		child:updateTreeLayout()
	end
end

--- Updates the transform objects of the entire branch.
--- Must be called after ui.Transform was modified.
--- Must be called after changing: x, y, width, height, anchor or origin
function Node:updateTreeTransform()
	self.transform:update()
	for _, v in ipairs(self.children) do
		v:updateTreeTransform()
	end
end

---@param e ui.MouseDownEvent
function Node:onMouseDown(e) end

---@param e ui.MouseUpEvent
function Node:onMouseUp(e) end

---@param e ui.MouseClickEvent
function Node:onMouseClick(e) end

---@param e ui.ScrollEvent
function Node:onScroll(e) end

---@param e ui.DragStartEvent
function Node:onDragStart(e) end

---@param e ui.DragEvent
function Node:onDrag(e) end

---@param e ui.DragEndEvent
function Node:onDragEnd(e) end

function Node:onHover() end

function Node:onHoverLost() end

---@param e ui.FocusEvent
function Node:onFocus(e) end

---@param e ui.FocusLostEvent
function Node:onFocusLost(e) end

---@param e ui.KeyDownEvent
function Node:onKeyDown(e) end

---@param e ui.KeyUpEvent
function Node:onKeyUp(e) end

---@param e ui.TextInputEvent
function Node:onTextInput(e) end

function Node:onKill() end

---@param message string
function Node:error(message)
	message = ("%s :: %s"):format(self.id or self.ClassName or "unnamed", message)
	if self.parent then
		self.parent:error(message)
	else
		error(message)
	end
end

function Node:assert(condition, message)
	if not condition then
		self:error(message)
	end
end

---@param field_name string
function Node:ensureExist(field_name)
	self:assert(self[field_name], ("The field `%s` is required"):format(field_name))
end

---@param axis ui.Axis
function Node:invalidateLayoutAxis(axis)
	self.layout_axis_invalidated = bit.bor(self.layout_axis_invalidated, axis)
end

---@return number
function Node:getLayoutWidth()
	return self.width - self.padding_left - self.padding_right
end

---@return number
function Node:getLayoutHeight()
	return self.height - self.padding_top - self.padding_bottom
end

---@return number, number
function Node:getLayoutDimensions()
	return self:getLayoutWidth(), self:getLayoutHeight()
end

---@param x number
---@param y number
function Node:setPosition(x, y)
	self.x = x
	self.y = y
	self:invalidateLayoutAxis(Axis.Both)
end

---@param width number
function Node:setWidth(width)
	self.width = width
	self:invalidateLayoutAxis(Axis.X)
end

---@param height number
function Node:setHeight(height)
	self.height = height
	self:invalidateLayoutAxis(Axis.Y)
end

---@param width number
---@param height number
function Node:setDimensions(width, height)
	self.width = width
	self.height = height
	self:invalidateLayoutAxis(Axis.Both)
end

return Node
