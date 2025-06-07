local IEventHandler = require("ui.IEventHandler")

---@class ui.SphereEventHandler : ui.IEventHandler
---@operator call: ui.SphereEventHandler
---@field event_listeners {[string]: {[ui.Node]: true}}
---@field cancelable_event_listeners {[string]: ui.Node[]}
---@field focus {[string]: ui.Node}
local SphereEventHandler = IEventHandler + {}

---@param name string
---@param cancelable boolean?
function SphereEventHandler:registerEvent(name, cancelable)
	local list = cancelable and self.cancelable_event_listeners or self.event_listeners
	list[name] = {}
end

---@param node ui.Node
function SphereEventHandler:collectNodeEvents(node)
	for event_name, list in pairs(self.event_listeners) do
		if node[event_name] then
			list[node] = true
		end
	end
end

---@param node ui.Node
function SphereEventHandler:removeNodeEvents(node)
	for _, list in pairs(self.event_listeners) do
		list[node] = nil
	end
end

---@param node ui.Node
function SphereEventHandler:collectCancelableEvents(node)
	for event_name, _ in pairs(self.cancelable_event_listeners) do
		self.cancelable_event_listeners[event_name] = {}
	end

	self:collectCancelableEventsFrom(node)
end

---@param name string
function SphereEventHandler:dispatchEvent(name, ...)
	local focused_node = self.focus[name]
	if focused_node then
		focused_node[name](focused_node, ...)
		return
	end

	if self.event_listeners[name] then
		for node, _ in pairs(self.event_listeners[name]) do
			if not node.is_killed then
				node[name](node, ...)
			end
		end
		return
	elseif self.cancelable_event_listeners[name] then
		for _, node in ipairs(self.cancelable_event_listeners[name]) do
			if not node.is_killed then
				if node[name](node, ...) then
					break
				end
			end
		end
		return
	end

	print(("Event %s is not registered"):format(name))
end

---@param node ui.Node
function SphereEventHandler:collectCancelableEventsFrom(node)
	for event_name, list in pairs(self.cancelable_event_listeners) do
		if node[event_name] then
			table.insert(list, node)
		end
	end

	for _, child in ipairs(node.children) do
		self:collectCancelableEventsFrom(child)
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
