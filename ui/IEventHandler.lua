local class = require("class")

---@class ui.IEventHandler
---@operator call: ui.IEventHandler
local IEventHandler = class()

---@param name string
---@param cancelable boolean?
function IEventHandler:registerEvent(name, cancelable) end

---@param node ui.Node
function IEventHandler:nodeAdded(node) end

---@param node ui.Node
function IEventHandler:nodeRemoved(node) end

---@param name string
function IEventHandler:dispatchEvent(name, ...) end

---@param node ui.Node
---@param event_name string
function IEventHandler:setFocus(node, event_name) end

---@param node ui.Node
function IEventHandler:clearFocus(node) end

return IEventHandler
