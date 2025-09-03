local class = require("class")
local table_util = require("table_util")

---@class ui.Node.Params
---@field z number? z-index, 1 is above 0
---@field is_disabled boolean?

---@class ui.Node : ui.Node.Params
---@operator call: ui.Node
---@field id string?
---@field children ui.Node[]
---@field parent ui.Node?
---@field dependencies ui.Dependencies
---@field is_killed boolean
---@field handle_mouse_input boolean
---@field handle_keyboard_input boolean
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
	self.children = self.children or {}
end

--- Used for internal classes. Clases should always call base.beforeLoad()
function Node:beforeLoad() end

function Node:load() end

---@param dt number
function Node:update(dt) end

function Node:draw() end

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

	local awaiting = nil

	if #node.children ~= 0 then
		awaiting = {}
		table_util.copy(node.children, awaiting)
		node.children = {}
	end

	node.parent = self
	node.dependencies = self.dependencies
	node:beforeLoad()
	node:load()

	if awaiting then
		for i, v in ipairs(awaiting) do
			node:add(v)
		end
	end

	return node
end

---@param node ui.Node
function Node:remove(node)
	for i, child in ipairs(self.children) do
		if child == node then
			table.remove(self.children, i)
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

---@param e ui.MouseDownEvent
function Node:onMouseDown(e) end

---@param e ui.MouseUpEvent
function Node:onMouseUp(e) end

---@param e ui.MouseClickEvent
function Node:onMouseClick(e) end

---@param e ui.ScrollEvent
function Node:onScroll(e) end

---@param e ui.DragStartEvent
function Node:onDragStart(e) end

---@param e ui.DragEvent
function Node:onDrag(e) end

---@param e ui.DragEndEvent
function Node:onDragEnd(e) end

function Node:onHover() end

function Node:onHoverLost() end

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

---@param field_name string
function Node:ensureExist(field_name)
	self:assert(self[field_name], ("The field `%s` is required"):format(field_name))
end

return Node
