local class = require("class")

---@class ui.INode
---@field parent ui.INode?
---@field children ui.INode[]
local INode = class()

---@param node ui.INode
function INode:add(node) end

---@param node ui.INode
function INode:remove(node) end

return INode
