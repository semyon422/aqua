local class = require("class")
local Enums = require("ui.layout.Enums")
local Axis = Enums.Axis

---@class ui.LayoutStrategy
---@operator call: ui.LayoutStrategy
---@field engine ui.LayoutEngine
local LayoutStrategy = class()

---@param engine ui.LayoutEngine
function LayoutStrategy:new(engine)
	self.engine = engine
end

---Measure all children and set node size
---@param node ui.Node
---@param axis_idx ui.Axis
---@param dependency_dirty boolean?
function LayoutStrategy:measure(node, axis_idx, dependency_dirty) end

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

---Arrange a child node using the correct strategy
---@param node ui.Node
---@param dependency_dirty boolean?
function LayoutStrategy:arrangeChild(node, dependency_dirty)
	self.engine:arrange(node, dependency_dirty)
end

return LayoutStrategy
