local class = require("class")
local Box = require("ui.Box")

---@class ui.Composition.Node
---@operator call: ui.Composition.Node
---@field parent ui.Composition.Node?
---@field x number
---@field y number
---@field layout_x number
---@field layout_y number
---@field width number
---@field height number
---@field views ui.View[]
---@field nodes ui.Composition.Node[]
---@field combined ui.View[] | ui.Composition.Node[]
local Node = class()

Node.LEFT = 1
Node.UP = 2
Node.DOWN = 3
Node.RIGHT = 4
Node._is_node = true

---@param t ({[string]: any} | ui.View[] | ui.Composition.Node[])?
function Node:new(t)
	t = t or {}
	self.x = 0
	self.y = 0
	self.layout_x = 0
	self.layout_y = 0
	self.width = 0
	self.height = 0
	self.views = {}
	self.nodes = {}
	self.combined = {}

	for _, v in ipairs(t) do
		if v._is_view then
			v.box = Box()
			table.insert(self.views, v)
		elseif v._is_node then
			v.parent = self
			table.insert(self.nodes, v)
		end

		table.insert(self.combined, v)
	end

	self:applyParams(t)
end

---@param t {[string]: any}
function Node:applyParams(t) end

function Node:measure() error("Not implemented") end

---@param available_w number
---@param available_h number
function Node:grow(available_w, available_h) error("Not implemented") end

function Node:arrange() error("Not implemented") end

---@param t ui.View[]
function Node:insertViewsInto(t)
	for _, v in ipairs(self.combined) do
		if v._is_view then ---@cast v ui.View
			table.insert(t, v)
		elseif v._is_node then ---@cast v ui.Composition.Node
			v:insertViewsInto(t)
		end
	end
end

return Node
