local class = require("class")
local INode = require("ui.INode")
local LayoutBox = require("ui.layout.LayoutBox")
local IInputHandler = require("ui.input.IInputHandler")
local Transform = require("ui.Transform")
local table_util = require("table_util")

local LayoutEnums = require("ui.layout.Enums")
local Arrange = LayoutEnums.Arrange
local JustifyContent = LayoutEnums.JustifyContent
local AlignItems = LayoutEnums.AlignItems
local Pivot = LayoutEnums.Pivot

---@alias ui.Color [number, number, number, number]
---@alias ui.BlendMode { color: string, alpha: string }

---@class view.Node : ui.HasLayoutBox, ui.Inputs.Node
---@operator call: view.Node
---@field id string?
---@field parent view.Node
---@field children view.Node[]
---@field draw? fun(self: view.Node)
---@field color ui.Color?
---@field blend_mode ui.BlendMode?
---@field stencil boolean?
---@field draw_to_canvas boolean?
---@field canvas love.Canvas?
---@field origin ui.Pivot
---@field anchor ui.Pivot
---@field inputs ui.Inputs
---@field mounted boolean Is the node inside a main tree?
local Node = class() + INode + IInputHandler

Node.State = {
	AwaitsMount = 1,
	Loaded = 2,
	Ready = 3,
	Killed = 4,
}

local State = Node.State

function Node:new()
	self.layout_box = LayoutBox()
	self.transform = Transform()
	self.z = 0
	self.children = {}
	self.mouse_over = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self.is_disabled = false
	self.state = State.AwaitsMount
	self.origin = Pivot.TopLeft
	self.anchor = Pivot.TopLeft
end

--- Takes a table with parameters and applies them using setters
--- Look at the Node.Setters at the end of the file, only those can be applied
--- Classes can extend Setters
---@param params {[string]: any}
function Node:setup(params)
	assert(params, "No params passed to init(), don't forget to pass them when you override the function")
	for k, v in pairs(params) do
		local f = self.Setters[k]
		if f then
			if f == true then
				self[k] = v ---@diagnostic disable-line: no-unknown
			else
				f(self, v)
			end
		end
	end
end

---@param inputs ui.Inputs
--- Mounts the node and the entire branch to the main tree.
--- This gives every node all required dependencies and loads them.
function Node:mount(inputs)
	self.inputs = inputs
	self:load()
	self.state = State.Loaded

	for _, v in ipairs(self.children) do
		if v.state == State.AwaitsMount then
			v:mount(self.inputs)
		end
	end
end

function Node:load() end

--- Will be called once right before the update method after the node was loaded
function Node:loadComplete() end

---@param dt number
function Node:update(dt) end

---@generic T : view.Node
---@param node T
---@param params {[string]: any}? Passes parameters to Node:setup()
---@return T
function Node:add(node, params)
	---@cast node view.Node
	local inserted = false
	assert(node.state ~= nil, "Did you forgot to call a base Node:new()?")

	node.parent = self

	if params then
		node:setup(params)
	end

	for i, child in ipairs(self.children) do
		if node.z < child.z then
			table.insert(self.children, i, node)
			inserted = true
			break
		end
	end

	if not inserted then
		table.insert(self.children, node)
	end

	if self.state ~= State.AwaitsMount then
		node:mount(self.inputs)
	end

	return node
end

---@param mouse_x number
---@param mouse_y number
---@param imx number
---@param imy number
function Node:isMouseOver(mouse_x, mouse_y, imx, imy)
	return imx >= 0 and imx < self.layout_box.x.size and imy >= 0 and imy < self.layout_box.y.size
end

---@param node view.Node
function Node:remove(node)
	for i, child in ipairs(self.children) do
		if child == node then
			table.remove(self.children, i)
			return
		end
	end
end

--- Marks the node to be killed at the end of the Engine:updateTree().
--- Doesn't remove it from the tree.
function Node:kill()
	self.state = State.Killed
end

--- DO NOT CALL THIS OUTSIDE OF Engine CLASS
--- Removes references to other nodes.
function Node:destroy()
	if self.children then
		for i = #self.children, 1, -1 do
			local child = self.children[i]
			child.parent = nil
			child:destroy()
		end
		table_util.clear(self.children)
	end

	-- Not necessary, but GC will destory these faster
	self.children = nil
	self.inputs = nil
	self.layout_box = nil
	self.transform = nil
end

--- Must be called after the layout update
--- Sets layout X, layout Y and origins with anchors in the ui.Transform
function Node:updateTreeLayout()
	local x, y = 0, 0
	local layout_box = self.layout_box
	local parent_tf ---@type love.Transform?

	if self.parent then
		local plb = self.parent.layout_box
		x = layout_box.x.pos + self.anchor.x * plb:getLayoutWidth() + plb.x.padding_start
		y = layout_box.y.pos + self.anchor.y * plb:getLayoutHeight() + plb.y.padding_start
		parent_tf = self.parent.transform:get()
	else
		x = layout_box.x.pos
		y = layout_box.y.pos
	end

	local tf = self.transform
	tf.layout_x = x
	tf.layout_y = y
	tf.origin_x = self.origin.x * layout_box.x.size
	tf.origin_y = self.origin.y * layout_box.y.size
	tf.parent_transform = parent_tf

	layout_box:markValid()

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

---@return number
function Node:getWidth()
	return self.layout_box.x.preferred_size
end

---@return number
function Node:getHeight()
	return self.layout_box.y.preferred_size
end

---@return number
--- Returns an actual width in the layout
function Node:getCalculatedWidth()
	return self.layout_box.x.size
end

---@return number
--- Returns an actual height in the layout
function Node:getCalculatedHeight()
	return self.layout_box.y.size
end

---@param v "auto" | "fit" | string | number
function Node:setWidth(v)
	if v == "auto" then
		self.layout_box:setWidthAuto()
	elseif v == "fit" then
		self.layout_box:setWidthFit()
	elseif type(v) == "string" then
		if v:sub(-1) == "%" then
			local num_part = v:sub(1, -2)
			local num = tonumber(num_part)
			if num then
				self.layout_box:setWidthPercent(num * 0.01)
			end
		end
	elseif type(v) == "number" then
		self.layout_box:setWidth(v)
	end
end

---@param v "auto" | "fit" | string | number
function Node:setHeight(v)
	if v == "auto" then
		self.layout_box:setHeightAuto()
	elseif v == "fit" then
		self.layout_box:setHeightFit()
	elseif type(v) == "string" then
		if v:sub(-1) == "%" then
			local num_part = v:sub(1, -2)
			local num = tonumber(num_part)
			if num then
				self.layout_box:setHeightPercent(num * 0.01)
			end
		end
	elseif type(v) == "number" then
		self.layout_box:setHeight(v)
	end
end

---@param v number
function Node:setMinWidth(v)
	self.layout_box:setMinWidth(v)
end

---@param v number
function Node:setMaxWidth(v)
	self.layout_box:setMaxWidth(v)
end

---@param v number
function Node:setMinHeight(v)
	self.layout_box:setMinHeight(v)
end

---@param v number
function Node:setMaxHeight(v)
	self.layout_box:setMaxHeight(v)
end

---@enum (key) ui.PivotString
local pivot = {
	top_left = Pivot.TopLeft,
	top_center = Pivot.TopCenter,
	top_right = Pivot.TopRight,
	center_left = Pivot.CenterLeft,
	center = Pivot.Center,
	center_right = Pivot.CenterRight,
	bottom_left = Pivot.BottomLeft,
	bottom_center = Pivot.BottomCenter,
	bottom_right = Pivot.BottomRight
}

---@param v ui.PivotString
function Node:setOrigin(v)
	self.origin = pivot[v]
	self.transform.invalidated = true
end

---@param v ui.PivotString
function Node:setAnchor(v)
	self.anchor = pivot[v]
	self.transform.invalidated = true
end

---@param v ui.PivotString
function Node:setPivot(v)
	self.origin = pivot[v]
	self.anchor = pivot[v]
	self.transform.invalidated = true
end

---@param x number
function Node:setX(x)
	self.transform:setX(x)
end

---@param y number
function Node:setY(y)
	self.transform:setY(y)
end

---@param sx number
function Node:setScaleX(sx)
	self.transform:setScaleX(sx)
end

---@param sy number
function Node:setScaleY(sy)
	self.transform:setScaleY(sy)
end

---@param a number
function Node:setAngle(a)
	self.transform:setAngle(a)
end

---@param v "absolute" | "flow_h" | "flow_v"
function Node:setArrange(v)
	local arrange = Arrange.Absolute

	if v == "absolute" then
		arrange = Arrange.Absolute
	elseif v == "flow_h" then
		arrange = Arrange.FlowH
	elseif v == "flow_v" then
		arrange = Arrange.FlowV
	end

	self.layout_box:setArrange(arrange)
end

---@param v boolean
function Node:setReversed(v)
	self.layout_box:setReversed(v)
end

---@param v number
function Node:setChildGap(v)
	self.layout_box:setChildGap(v)
end

---@param str string
---@return ui.AlignItems
local function str_to_align(str)
	if str == "center" then
		return AlignItems.Center
	elseif str == "end" then
		return AlignItems.End
	elseif str == "stretch" then
		return AlignItems.Stretch
	end
	return AlignItems.Start
end

---@param v "start" | "center" | "end" | "stretch"
function Node:setAlignItems(v)
	self.layout_box:setAlignItems(str_to_align(v))
end

---@param v ("start" | "center" | "end" | "stretch")?
function Node:setAlignSelf(v)
	if not v then
		self.layout_box:setAlignSelf(nil)
		return
	end
	self.layout_box:setAlignSelf(str_to_align(v))
end

---@param v "start" | "center" | "end" | "space_between"
function Node:setJustifyContent(v)
	local j = JustifyContent.Start
	if v == "center" then
		j = JustifyContent.Center
	elseif v == "end" then
		j = JustifyContent.End
	elseif v == "space_between" then
		j = JustifyContent.SpaceBetween
	end
	self.layout_box:setJustifyContent(j)
end

---@param v [number, number, number, number]
function Node:setPaddings(v)
	self.layout_box:setPaddings(v)
end

---@param v number
function Node:setGrow(v)
	self.layout_box:setGrow(v)
end

Node.Setters = {
	width = Node.setWidth,
	height = Node.setHeight,
	min_width = Node.setMinWidth,
	max_width = Node.setMaxWidth,
	min_height = Node.setMinHeight,
	max_height = Node.setMaxHeight,
	origin = Node.setOrigin,
	anchor = Node.setAnchor,
	pivot = Node.setPivot,
	x = Node.setX,
	y = Node.setY,
	scale_x = Node.setScaleX,
	scale_y = Node.setScaleY,
	angle = Node.setAngle,
	arrange = Node.setArrange,
	reversed = Node.setReversed,
	child_gap = Node.setChildGap,
	align_items = Node.setAlignItems,
	align_self = Node.setAlignSelf,
	justify_content = Node.setJustifyContent,
	padding = Node.setPaddings,
	grow = Node.setGrow,
	id = true,
	color = true,
	z = true,
	handles_mouse_input = true,
	handles_keyboard_input = true,
	is_disabled = true,
	blend_mode = true,
	stencil = true,
	draw_to_canvas = true,

	-- Events
	onKeyDown = true,
}

return Node
