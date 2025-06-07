local class = require("class")

---@class ui.Node
---@operator call: ui.Node
---@field id string?
---@field z number z-index, 1 is above 0
---@field children ui.Node[]
---@field parent ui.Node?
---@field root ui.ITreeRoot
---@field is_killed boolean
local Node = class()

function Node:new(params)
	if params then
		for k, v in pairs(params) do
			self[k] = v
		end
	end

	self.z = self.z or 0
	self.is_killed = false
	self.children = {}
end

function Node:load() end

---@generic T : ui.Node
---@param node T
---@return T
function Node:addChild(node)
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

	if not self.root then
		self:error(("No root node"))
	end

	node.parent = self
	node.root = self.root
	node:load()
	self.root:nodeAdded(node)
	return node
end

function Node:removeChild(node)
	for i, child in ipairs(self.children) do
		if child == node then
			self.root:nodeRemoved(node)
			table.remove(self.children, i)
			return
		end
	end
end

function Node:kill()
	self.parent:removeChild(self)
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

return Node
