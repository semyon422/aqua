local class = require("class")
local LayoutBox = require("ui.layout.LayoutBox")
local table_util = require("table_util")

local LayoutEnums = require("ui.layout.Enums")
local Arrange = LayoutEnums.Arrange
local JustifyContent = LayoutEnums.JustifyContent
local AlignItems = LayoutEnums.AlignItems

---@class ui.Node: ui.HasLayoutBox, ui.IInputHandler
---@operator call: ui.Node
---@field parent ui.Node?
---@field children ui.Node[]
---@field layout_box ui.LayoutBox
---@field inputs ui.Inputs
---@field is_disabled boolean
---@field handles_mouse_input boolean
---@field handles_keyboard_input boolean
---@field just_toggled_state boolean Used in enable()/disable() to tell the Engine that the state had changed
---@field mouse_over boolean
local Node = class()

Node.State = {
	AwaitsMount = 1,
	Loaded = 2,
	Ready = 3,
	Killed = 4,
}

local State = Node.State

function Node:new()
	self.layout_box = LayoutBox()
	self.children = {}
	self.mouse_over = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
	self.is_disabled = false
	self.just_toggled_state = false
	self.state = State.AwaitsMount
end

--- Takes a table with parameters and applies them using setters
---@param params {[string]: any}
function Node:setup(params)
	assert(params, "No params passed to init(), don't forget to pass them when you override the function")
	for k, v in pairs(params) do
		local f = self.Setters[k]
		if f then
			if f == true then
				self[k] = v
			else
				f(self, v)
			end
		end
	end
end

---@param inputs ui.Inputs
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

function Node:loadComplete() end

---@param dt number
function Node:update(dt) end

---@generic T : ui.Node
---@param node T
---@param params {[string]: any}?
---@return T
function Node:add(node, params)
	---@cast node ui.Node
	assert(node.state ~= nil, "Did you forgot to call a base Node:new()?")

	node.parent = self

	if params then
		node:setup(params)
	end

	table.insert(self.children, node)

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

function Node:disable()
	if not self.is_disabled then
		self.is_disabled = true
		self.just_toggled_state = true
	end
end

function Node:enable()
	if self.is_disabled then
		self.is_disabled = false
		self.just_toggled_state = true
	end
end

function Node:destroy()
	if self.children then
		for i = #self.children, 1, -1 do
			local child = self.children[i]
			child.parent = nil
			child:destroy()
		end
		table_util.clear(self.children)
	end

	self.children = nil
	self.inputs = nil
	self.layout_box = nil
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
function Node:getCalculatedWidth()
	return self.layout_box.x.size
end

---@return number
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
	arrange = Node.setArrange,
	reversed = Node.setReversed,
	child_gap = Node.setChildGap,
	align_items = Node.setAlignItems,
	align_self = Node.setAlignSelf,
	justify_content = Node.setJustifyContent,
	padding = Node.setPaddings,
	grow = Node.setGrow,
	id = true,
	handles_mouse_input = true,
	handles_keyboard_input = true,
	is_disabled = true,
}

return Node
