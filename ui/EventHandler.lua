local class = require("class")
local events = require("ui.Events")

---@class ui.EventHandler
---@operator call: ui.EventHandler
---@field events_listeners {[string]: ui.Node[]}
local EventHandler = class()

---@param node ui.Node
function EventHandler:new(node)
	self.root = node
	self.should_rebuild = false
end

function EventHandler:deferBuild()
	self.should_rebuild = true
end

---@param node ui.Node
function EventHandler:collectEvents(node)
	for _, k in ipairs(events) do
		if node[k] then
			table.insert(self.events_listeners[k], node)
		end
	end

	if not node.children then
		return
	end

	table.sort(node.children, function (a, b)
		return a.z > b.z
	end)

	for _, child in ipairs(node.children) do
		self:collectEvents(child)
	end
end

function EventHandler:build()
	self.should_rebuild = false
	self.events_listeners = {}

	for _, k in ipairs(events) do
		self.events_listeners[k] = {}
	end

	self:collectEvents(self.root)
end

function EventHandler:receive()
	if self.should_rebuild then
		self:build()
	end
end

return EventHandler
