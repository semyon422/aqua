local class = require("class")

---@class ui.ITreeRoot
---@operator call: ui.ITreeRoot
local ITreeRoot = class()

---@param node ui.Node
function ITreeRoot:nodeAdded(node) end

---@param node ui.Node
function ITreeRoot:nodeRemoved(node) end

---@param event {name: string, [string]: any, [integer]: any }
function ITreeRoot:receive(event) end

return ITreeRoot
