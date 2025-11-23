local class = require("class")
local INode = require("ui.INode")
local LayoutBox = require("ui.layout.LayoutBox")
local IInputHandler = require("ui.input.IInputHandler")
local NodeTransform = require("ui.nya.NodeTransform")

---@alias ui.Color [number, number, number, number]

---@class nya.Node : ui.INode, ui.HasLayoutBox, ui.IInputHandler
---@operator call: nya.Node
---@field id string?
---@field parent nya.Node
---@field children nya.Node[]
---@field context nya.Context
---@field draw? fun(self: nya.Node)
---@field style ui.Style?
local Node = class() + INode + IInputHandler

Node.ClassName = "Node"

Node.State = {
	Created = 1,
	Loaded = 2,
	Ready = 3,
	Killed = 4,
}

--[[
local x = {}

local PARAMS = {
	id = x.string().optional(),
	z = x.number().optional(),
	is_disabled = x.boolean().optional(),
	handles_mouse_input = x.boolean().optional(),
	handles_keyboard_input = x.boolean().optional(),

	draw = x.func().optional(),
	update = x.func().optional(),

	mouse_over = x.forbidden(),
	context = x.forbidden(),
	parent = x.forbidden(),
	children = x.forbidden(),
	transform = x.forbidden(),
	layout_box = x.forbidden(),
	state = x.forbidden()
}
]]

local State = Node.State

---@param params {[string]: any}
function Node:new(params)
	self.layout_box = LayoutBox()
	self.transform = NodeTransform()
	self.z = 0
	self.children = {}
	self.mouse_over = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self.is_disabled = false
	self.state = State.Created

	if params then
		for k, v in pairs(params) do
			self[k] = v
		end
	end
end

function Node:load() end

--- Will be called once right before the update method after the node was loaded
function Node:loadComplete() end

---@param dt number
function Node:update(dt) end

---@generic T : nya.Node
---@param node T
---@return T
function Node:add(node)
	---@cast node nya.Node
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
	return imx >= 0 and imx < self.layout_box.width and imy >= 0 and imy < self.layout_box.height
end

---@param node nya.Node
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

function Node:onKill() end

--- Must be called after the layout update
--- Sets layout X, layout Y and origins with anchors in the ui.Transform
function Node:updateTreeLayout()
	local x, y = 0, 0
	local layout_box = self.layout_box
	local parent_tf ---@type love.Transform?

	if self.parent then
		local plb = self.parent.layout_box
		x = layout_box.x + layout_box.anchor.x * plb:getLayoutWidth() + plb.padding_left
		y = layout_box.y + layout_box.anchor.y * plb:getLayoutHeight() + plb.padding_top
		parent_tf = self.parent.transform:get()
	else
		x = layout_box.x
		y = layout_box.y
	end

	local tf = self.transform
	tf.layout_x = x
	tf.layout_y = y
	tf.origin_x = layout_box.origin.x * layout_box.width
	tf.origin_y = layout_box.origin.y * layout_box.height
	tf.parent_transform = parent_tf

	layout_box:markValid()

	if self.style then
		self.style:setDimensions(layout_box.width, layout_box.height)
	end

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

return Node
