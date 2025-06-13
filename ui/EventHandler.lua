local class = require("class")

---@class ui.EventHandler
---@operator call: ui.EventHandler
---@field event_listeners {[string]: ui.Node[]}
---@field focus {[string]: ui.Node}
local EventHandler = class()

function EventHandler:new()
	self.event_listeners = {}
	self.focus = {}
	self.collect_events = false
end

---@param node ui.Node
function EventHandler:setRoot(node)
	self.root = node
end

---@param name string
function EventHandler:registerEvent(name)
	if self.event_listeners[name] then
		return
	end
	self.event_listeners[name] = {}
	self.collect_events = true
end

---@param node ui.Node
function EventHandler:nodeAdded(node)
	self.collect_events = true
end

---@param node ui.Node
function EventHandler:nodeRemoved(node)
	self:clearFocus(node)
	self.collect_events = true
end

---@param name string
function EventHandler:dispatchEvent(name, ...)
	if self.collect_events then
		self:collectEvents()
	end

	if not self.event_listeners[name] then
		print(("Event %s is not registered"):format(name))
		return
	end

	local focused_node = self.focus[name]
	if focused_node and not focused_node.is_disabled then
		focused_node[name](focused_node, ...)
		return
	end

	for _, node in ipairs(self.event_listeners[name]) do
		if not node.is_disabled then
			if node[name](node, ...) then
				break
			end
		end
	end
end

function EventHandler:collectEvents()
	for event_name, _ in pairs(self.event_listeners) do
		self.event_listeners[event_name] = {}
	end
	self:collectEventsFrom(self.root)
	self.collect_events = false
end

---@param node ui.Node
function EventHandler:collectEventsFrom(node)
	if not node then
		error("Root node is nil in event handler")
	end

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
function EventHandler:setFocus(node, event_name)
	if not node[event_name] then
		node:error(("Trying to focus on %s which isn't implemented"):format(event_name))
		return
	end
	self.focus[event_name] = node
end

---@param node ui.Node
function EventHandler:clearFocus(node)
	for k, v in pairs(self.focus) do
		if v == node then
			self.focus[k] = nil
		end
	end
end

return EventHandler
