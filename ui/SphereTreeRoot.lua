local Node = require("ui.Node")
local SphereEventHandler = require("ui.SphereEventHandler")
local ITreeRoot = require("ui.ITreeRoot")

---@class ui.SphereTreeRoot : ui.Node, ui.SphereEventHandler, ui.ITreeRoot
---@operator call: ui.SphereTreeRoot
local SphereTreeRoot = Node + SphereEventHandler + ITreeRoot + {}

function SphereTreeRoot:new()
	self.root = self
	self.children = {}
	self.event_listeners = {}
	self.cancelable_event_listeners = {}
	self.focus = {}
	self.tree_updated = false
end

---@param node ui.Node
function SphereTreeRoot:nodeAdded(node)
	self.tree_updated = true
	self:collectNodeEvents(node)
end

---@param node ui.Node
function SphereTreeRoot:nodeRemoved(node)
	self.tree_updated = true
	self:removeNodeEvents(node)
	self:clearFocus(node)
end

function SphereTreeRoot:update()
	if self.tree_updated then
		self.tree_updated = false
		self:collectCancelableEvents(self)
		return
	end
end


return SphereTreeRoot
