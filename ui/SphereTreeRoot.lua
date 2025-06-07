local Node = require("ui.Node")
local ITreeRoot = require("ui.ITreeRoot")

---@class ui.SphereTreeRoot : ui.Node, ui.ITreeRoot
---@operator call: ui.SphereTreeRoot
local SphereTreeRoot = Node + ITreeRoot + {}

---@param event_handler ui.SphereEventHandler
function SphereTreeRoot:new(event_handler)
	self.root = self
	self.children = {}
	self.event_handler = event_handler
	event_handler:setRoot(self)
end

---@param node ui.Node
function SphereTreeRoot:nodeAdded(node)
	self.event_handler:nodeAdded(node)
end

---@param node ui.Node
function SphereTreeRoot:nodeRemoved(node)
	self.event_handler:nodeRemoved(node)
end

---@param name string
function SphereTreeRoot:dispatchEvent(name, ...)
	self.event_handler:dispatchEvent(name, ...)
end

return SphereTreeRoot
