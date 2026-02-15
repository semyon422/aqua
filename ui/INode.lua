local class = require("class")

---@class ui.INode
---@field parent ui.INode?
---@field children ui.INode[]
local INode = class()

---@generic T: ui.INode
---@param node T
---@return T
function INode:add(node) return node end

---@param node ui.INode
function INode:remove(node) end

return INode
