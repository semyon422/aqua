local class = require("class")
local Enums = require("ui.layout.Enums")
local Axis = Enums.Axis

---@class ui.LayoutStrategy
---@operator call: ui.LayoutStrategy
local LayoutStrategy = class()

---Measure all children and set node size
---@param node ui.Node
---@param axis_idx ui.Axis
function LayoutStrategy:measure(node, axis_idx) end

---Distribute extra space to growing children
---@param node ui.Node
---@param axis_idx ui.Axis
function LayoutStrategy:grow(node, axis_idx) end

---Position all children
---@param node ui.Node
function LayoutStrategy:arrange(node) end

---Get intrinsic size from node if available
---@param node ui.Node
---@param axis_idx ui.Axis
---@param constraint number? For height, pass width
---@return number?
function LayoutStrategy:getIntrinsicSize(node, axis_idx, constraint)
	if node.getIntrinsicSize then
		return node:getIntrinsicSize(axis_idx, constraint)
	end
	return nil
end

---Get axis from node
---@param node ui.Node
---@param axis_idx ui.Axis
---@return ui.LayoutAxis
function LayoutStrategy:getAxis(node, axis_idx)
	return (axis_idx == Axis.X) and node.layout_box.x or node.layout_box.y
end

return LayoutStrategy
