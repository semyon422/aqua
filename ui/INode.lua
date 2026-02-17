local class = require("class")
local IInputHandler = require("ui.input.IInputHandler")

---@class ui.INode : ui.IInputHandler, ui.HasLayoutBox
---@field parent ui.INode?
---@field children ui.INode[]
---@field is_disabled boolean
local INode = class() + IInputHandler

function INode:new()
	error("INode interface should not be used. Use ui.view.Node only.")
end

---@generic T: ui.INode
---@param node T
---@return T
function INode:add(node) return node end

---@param node ui.INode
function INode:remove(node) end

return INode
