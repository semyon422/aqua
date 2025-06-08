local IEventHandler = require("ui.IEventHandler")

---@class ui.SphereEventHandler : ui.IEventHandler
---@operator call: ui.SphereEventHandler
---@field event_listeners {[string]: ui.Node[]}
---@field focus {[string]: ui.Node}
local SphereEventHandler = IEventHandler + {}

function SphereEventHandler:new()
	self.event_listeners = {}
	self.focus = {}
	self.collect_events = false
end

---@param node ui.Node
function SphereEventHandler:setRoot(node)
	self.root = node
end

---@param name string
function SphereEventHandler:registerEvent(name)
	if self.event_listeners[name] then
		error(("Event %s is already registered"):format(name))
	end

	self.event_listeners[name] = {}
	self.collect_events = true
end

---@param node ui.Node
function SphereEventHandler:nodeAdded(node)
	self.collect_events = true
end

---@param node ui.Node
function SphereEventHandler:nodeRemoved(node)
	self:clearFocus(node)
	self.collect_events = true
end

---@param name string
function SphereEventHandler:dispatchEvent(name, ...)
	if self.collect_events then
		self:collectEvents()
	end

	if not self.event_listeners[name] then
		print(("Event %s is not registered"):format(name))
	end

	local focused_node = self.focus[name]
	if focused_node then
		focused_node[name](focused_node, ...)
		return
	end

	for _, node in ipairs(self.event_listeners[name]) do
		if node[name](node, ...) then
			break
		end
	end

end

function SphereEventHandler:collectEvents()
	for event_name, _ in pairs(self.event_listeners) do
		self.event_listeners[event_name] = {}
	end
	self:collectEventsFrom(self.root)
	self.collect_events = false
end

---@param node ui.Node
function SphereEventHandler:collectEventsFrom(node)
	for event_name, list in pairs(self.event_listeners) do
		if node[event_name] then
			table.insert(list, node)
		end
	end

	for _, child in ipairs(node.children) do
		self:collectEventsFrom(child)
	end
end

---@param node ui.Node
---@param event_name string
function SphereEventHandler:setFocus(node, event_name)
	if not node[event_name] then
		node:error(("Trying to focus on %s which isn't implemented"):format(event_name))
		return
	end
	self.focus[event_name] = node
end

function SphereEventHandler:clearFocus(node)
	for k, v in pairs(self.focus) do
		if v == node then
			self.focus[k] = nil
		end
	end
end

return SphereEventHandler
