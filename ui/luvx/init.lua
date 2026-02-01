local fields = require("ui.luvx.validation")

require("table.clear")

---@class core.LuvX
---@overload fun(metatable: view.Node, params: {[string]: any}, childen: view.Node[]?): nya.Node
local LuvX = {}

LuvX.props = {
	---@param node view.Node
	---@param size number | string
	width = function(node, size)
		local axis = node.layout_box.x
		axis.preferred_size, axis.mode = fields.width(size)
	end,

	---@param node view.Node
	---@param size number | string
	height = function(node, size)
		local axis = node.layout_box.y
		axis.preferred_size, axis.mode = fields.height(size)
	end,

	---@param node view.Node
	---@param size number
	min_width = function(node, size)
		node.layout_box.x.min_size = fields.min_width(size)
	end,

	---@param node view.Node
	---@param size number
	min_height = function(node, size)
		node.layout_box.y.min_size = fields.min_height(size)
	end,

	---@param node view.Node
	---@param size number
	max_width = function(node, size)
		node.layout_box.x.max_size = fields.max_width(size)
	end,

	---@param node view.Node
	---@param size number
	max_height = function(node, size)
		node.layout_box.y.max_size = fields.max_height(size)
	end,

	---@param node view.Node
	---@param padding table<number> | number
	padding = function(node, padding)
		local box = node.layout_box
		local l, t, b, r = fields.padding(padding)
		box.x.padding_start = l
		box.y.padding_start = t
		box.y.padding_end = b
		box.x.padding_end = r
	end,

	---@param node view.Node
	---@param arrange string
	arrange = function(node, arrange)
		node.layout_box.arrange = fields.arrange(arrange)
	end,

	---@param node view.Node
	---@param justify string
	justify_content = function(node, justify)
		node.layout_box.justify_content = fields.justify_content(justify)
	end,

	---@param node view.Node
	---@param align string
	align_items = function(node, align)
		node.layout_box.align_items = fields.align_items(align)
	end,

	---@param node view.Node
	---@param align string
	align_self = function(node, align)
		node.layout_box.align_self = fields.align_items(align)
	end,

	---@param node view.Node
	---@param value number
	grow = function(node, value)
		node.layout_box.grow = fields.grow(value)
	end,

	---@param node view.Node
	---@param value number
	child_gap = function(node, value)
		node.layout_box.child_gap = fields.child_gap(value)
	end,

	---@param node view.Node
	---@param pivot string
	origin = function(node, pivot)
		node.layout_box.origin = fields.origin(pivot)
	end,

	---@param node view.Node
	---@param pivot string
	anchor = function(node, pivot)
		node.layout_box.anchor = fields.anchor(pivot)
	end,

	---@param node view.Node
	---@param pivot string
	pivot = function(node, pivot)
		local p = fields.pivot(pivot)
		node.layout_box.origin = p
		node.layout_box.anchor = p
	end,

	---@param node view.Node
	---@param id string
	id = function(node, id)
		node.id = fields.id(id)
	end,

	---@param node view.Node
	---@param t table
	transform = function(node, t)
		local tf = node.transform
		t = fields.transform(t)
		tf:setPosition(t.x, t.y)
		tf:setAngle(t.angle)
		tf:setScale(t.sx, t.sy)
		tf:setShear(t.kx, t.ky)
	end,

	---@param node view.Node
	---@param z number
	z = function(node, z)
		node.z = fields.z(z)
	end,

	---@param node view.Node
	---@param color ui.Color
	color = function(node, color)
		node.color = fields.color(color)
	end,

	---@param node view.Node
	---@param v boolean
	handles_mouse_input = function(node, v)
		node.handles_mouse_input = fields.handles_mouse_input(v)
	end,

	---@param node view.Node
	---@param v boolean
	handles_keyboard_input = function(node, v)
		node.handles_keyboard_input = fields.handles_keyboard_input(v)
	end
}

-- Temporary tables
local params = {}   -- Mixed styles and props
local children = {} -- Mixed children
local leftovers = {} -- Leftover props from styles

---@param element view.Node | function
---@param ... ...
---@return view.Node
function LuvX.createElement(element, ...)
	local instance

	if type(element) == "function" then
		instance = element()
	elseif type(element) == "table" and not element.state then
		instance = element()
	else
		instance = element
	end

	table.clear(params)
	table.clear(children)
	table.clear(leftovers)

	for i = 1, select("#", ...) do
		local t = select(i, ...)

		if t.ClassName then -- is a node
			table.insert(children, t)
		else
			for k, v in pairs(t) do
				params[k] = v
			end
		end
	end

	if not next(params) then
		instance:init(leftovers)
		for _, v in ipairs(children) do
			instance:add(v)
		end
		return instance
	end

	for k, v in pairs(params) do
		if LuvX.props[k] then
			LuvX.props[k](instance, v)
		else
			leftovers[k] = v
		end
	end

	instance:init(leftovers)

	for _, child in ipairs(children) do
		instance:add(child)
	end

	return instance
end

local mt = {
	__call = function(t, ...)
		return t.createElement(...)
	end
}

setmetatable(LuvX, mt) ---@diagnostic disable-line

return LuvX
