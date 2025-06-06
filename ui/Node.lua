local class = require("class")

---@class ui.Node
---@operator call: ui.Node
---@field id string
---@field z number z-index, 1 is above 0
---@field parent ui.Node?
---@field children ui.Node[]?
---@field events {[string]: boolean}?
---@field event_handler ui.EventHandler
local Node = class()

function Node:new(params)
	if params then
		for k, v in pairs(params) do
			self[k] = v
		end
	end

	self.id = self.id or "Unnamed Node"
	self.z = self.z or 0
end

function Node:load() end

---@generic T : ui.Node
---@param node T
---@return T
function Node:addChild(node)
	if not self.children then
		self.children = {}
	end

	---@cast node ui.Node
	table.insert(self.children, node)
	node.parent = self
	node.event_handler = self.event_handler
	node:load()
	self.event_handler:deferBuild()
	return node
end

---@param node ui.Node
function Node:removeChild(node)
	for i, child in ipairs(self.children) do
		if child == node then
			table.remove(self.children, i)
			return
		end
	end
end

function Node:kill()
	if not self.parent then
		self:error("Can't kill the root")
		return
	end

	self.parent:removeChild(self)
	self.event_handler:deferBuild()

	if not self.children then
		return
	end

	for _, child in ipairs(self.children) do
		child:kill()
	end
end

---@param message string
function Node:error(message)
	message = ("%s :: %s"):format(self.id, message)
	if self.parent then
		self.parent:error(message)
	else
		error(message)
	end
end

return Node
