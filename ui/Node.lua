local class = require("class")

---@class ui.Node.Params
---@field z number? z-index, 1 is above 0
---@field is_disabled boolean?

---@class ui.Node : ui.Node.Params
---@operator call: ui.Node
---@field id string?
---@field children ui.Node[]
---@field parent ui.Node?
---@field event_handler ui.EventHandler
---@field dependencies ui.Dependencies
---@field is_killed boolean
local Node = class()

---@param params {[string]: any}
function Node:new(params)
	if params then
		for k, v in pairs(params) do
			self[k] = v
		end
	end

	self.z = self.z or 0
	self.is_disabled = self.is_disabled or false
	self.is_killed = false
	self.children = {}
end

function Node:load() end

---@generic T : ui.Node
---@param node T
---@return T
function Node:add(node)
	---@cast node ui.Node
	local inserted = false

	if #self.children ~= 0 then
		for i, child in ipairs(self.children) do
			if node.z > child.z then
				table.insert(self.children, i, node)
				inserted = true
				break
			end
		end
	end

	if not inserted then
		table.insert(self.children, node)
	end

	node.parent = self
	node.event_handler = self.event_handler
	node.dependencies = self.dependencies
	node:load()
	self.event_handler:nodeAdded(node)
	return node
end

---@param node ui.Node
function Node:remove(node)
	for i, child in ipairs(self.children) do
		if child == node then
			table.remove(self.children, i)
			self.event_handler:nodeRemoved(node)
			return
		end
	end
end

function Node:clearTree()
	for _, child in ipairs(self.children) do
		child:kill()
	end
	self.children = {}
end

function Node:kill()
	self.parent:remove(self)
	self.is_killed = true

	for _, child in ipairs(self.children) do
		child:kill()
	end
end

---@param message string
function Node:error(message)
	message = ("%s :: %s"):format(self.id or "unnamed", message)
	if self.parent then
		self.parent:error(message)
	else
		error(message)
	end
end

function Node:assert(condition, message)
	if not condition then
		self:error(message)
	end
end

return Node
