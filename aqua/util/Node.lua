local Class = require("aqua.util.Class")

local Node = Class:new()

Node.construct = function(self)
	self.prev = {}
	self.next = {}
	self.callbacks = {}
	self.pass = false
end

Node.node = function(self, data_or_node, init)
	local node = data_or_node

	if not data_or_node.init then
		node = Node:new()

		node.data = data_or_node
		if init then
			node.init = init
			node:init()
		end
	else
		node:init()
	end

	node.prev[#node.prev + 1] = self
	self.next[#self.next + 1] = node

	return node
end

Node.on = function(self, action, callback)
	local callbacks = self.callbacks
	callbacks[action] = callbacks[action] or {}
	table.insert(callbacks[action], callback)
end

Node.call = function(self, action, event)
	local callbacks = self.callbacks
	if callbacks[action] then
		for _, callback in ipairs(callbacks[action]) do
			callback(self, event)
		end
	end
	if self.pass then
		for _, node in ipairs(self.next) do
			node:call(action, event)
		end
	end
end

Node.callnext = function(self, action, event)
	self:call(action, event)
	for _, node in ipairs(self.next) do
		node:callnext(action, event)
	end
end

return Node
