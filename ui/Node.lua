local LayoutBox = require("ui.layout.LayoutBox")
local LayoutEnums = require("ui.layout.Enums")
local IInputHandler = require("ui.input.IInputHandler")
local table_util = require("table_util")

---@class ui.Node: ui.IInputHandler
---@operator call: ui.Node
---@field parent ui.Node?
---@field children ui.Node[]
---@field layout_box ui.LayoutBox
---@field getIntrinsicSize? fun(self: ui.Node, axis_idx: ui.Axis, constraint: number?): number
local Node = IInputHandler + {}

function Node:new()
	self.layout_box = LayoutBox()
	self.children = {}
	self.mouse_over = false
	self.handles_mouse_input = false
	self.handles_keyboard_input = false
end

---@generic T : ui.Node
---@param node T
---@return T
function Node:add(node)
	---@cast node ui.Node
	node.parent = self
	node.layout_box:markDirty(LayoutEnums.Axis.Both)
	table.insert(self.children, node)
	return node
end

---@param mouse_x number
---@param mouse_y number
function Node:isMouseOver(mouse_x, mouse_y)
	return mouse_x >= 0 and mouse_x < self.layout_box.x.size and mouse_y >= 0 and mouse_y < self.layout_box.y.size
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
	self.layout_box = nil
end

return Node
