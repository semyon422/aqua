local class = require("class")

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
---@field canvas love.Canvas? Used for style
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
	self.x = 0
	self.y = 0
	self.z = 0
	self.angle = 0
	self.scale_x = 1
	self.scale_y = 1
	self.origin = Pivot.TopLeft
	self.anchor = Pivot.TopLeft
	self.width = 0
	self.height = 0
	self.width_mode = SizeMode.Fixed
	self.height_mode = SizeMode.Fixed
	self.padding_left = 0
	self.padding_right = 0
	self.padding_top = 0
	self.padding_bottom = 0
	self.child_gap = 0
	self.arrange = Arrange.Absolute
	self.transform = love.math.newTransform()
	self.mouse_over = false
	self.invalidate_axis = Axis.None
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self.is_disabled = false
	self.children = {}
	self.state = State.Created

	if params then
		Node.TransformParams(self, params)
	end

	if self.style then
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
function Node:invalidateAxis(axis)
	self.invalidate_axis = bit.bor(self.invalidate_axis, axis)
end

function Node:dimensionsChanged()
	if self.style then
		self.style:setDimensions(self.width, self.height)
	end
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
function Node:setX(x)
	self.x = x
	self:invalidateAxis(Axis.X)
end

---@param y number
function Node:setY(y)
	self.y = y
	self:invalidateAxis(Axis.Y)
end

---@param x number
---@param y number
function Node:setPosition(x, y)
	self.x = x
	self.y = y
	self:invalidateAxis(Axis.Both)
end

---@param width number
function Node:setWidth(width)
	self.width = width
	self:invalidateAxis(Axis.X)
end

---@param height number
function Node:setHeight(height)
	self.height = height
	self:invalidateAxis(Axis.Y)
end

---@param width number
---@param height number
function Node:setDimensions(width, height)
	self.width = width
	self.height = height
	self:invalidateAxis(Axis.Both)
end

---@param sx number
---@param sy number
function Node:setScale(sx, sy)
	self.scale_x = sx
	self.scale_y = sy
	self.invalidate_axis = Axis.Both
end

return Node
