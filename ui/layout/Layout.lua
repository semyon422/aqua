local class = require("class")
local Box = require("ui.Box")

local percent_pattern = "^(%-?%d+%.?%d*)%%$"

---@alias ui.LayoutSize number|string
---@alias ui.LayoutAlign [number, number]
---@alias ui.LayoutPadding number|[number, number]|[number, number, number, number]

---@class ui.LayoutNode
---@field id string?
---@field w ui.LayoutSize?
---@field h ui.LayoutSize?
---@field align ui.LayoutAlign?
---@field padding ui.LayoutPadding?
---@field arrange "stack"|"row"|"col"?
---@field children ui.LayoutNode[]?

---@class ui.Layout.Config
---@field root ui.LayoutNode
---@field target_height number?

---@class ui.Layout
---@operator call: ui.Layout
---@field boxes {[string]: ui.Box}
---@field root ui.LayoutNode
---@field target_height number?
local Layout = class()

---@param value any
---@param field string
---@param node ui.LayoutNode
local function validate_size(value, field, node)
	if value == nil or value == "*" or type(value) == "number" then
		return
	end
	if type(value) == "string" and value:match(percent_pattern) then
		return
	end
	error(("[ui.Layout] Invalid %s %q for node %s"):format(field, tostring(value), node.id or "<anonymous>"))
end

---@param align any
---@param node ui.LayoutNode
local function validate_align(align, node)
	if align == nil then
		return
	end
	if type(align) ~= "table" or type(align[1]) ~= "number" or type(align[2]) ~= "number" then
		error(("[ui.Layout] Invalid align for node %s"):format(node.id or "<anonymous>"))
	end
end

---@param padding any
---@param node ui.LayoutNode
local function validate_padding(padding, node)
	if padding == nil then
		return
	end
	if type(padding) == "number" then
		return
	end
	if type(padding) ~= "table" then
		error(("[ui.Layout] Invalid padding for node %s"):format(node.id or "<anonymous>"))
	end

	local count = #padding
	if count ~= 2 and count ~= 4 then
		error(("[ui.Layout] Invalid padding for node %s"):format(node.id or "<anonymous>"))
	end

	for i = 1, count do
		if type(padding[i]) ~= "number" then
			error(("[ui.Layout] Invalid padding for node %s"):format(node.id or "<anonymous>"))
		end
	end
end

---@param arrange any
---@param node ui.LayoutNode
local function validate_arrange(arrange, node)
	if arrange == nil or arrange == "stack" or arrange == "row" or arrange == "col" then
		return
	end
	error(("[ui.Layout] Invalid arrange %q for node %s"):format(tostring(arrange), node.id or "<anonymous>"))
end

---@param padding ui.LayoutPadding?
---@return number, number, number, number
local function resolve_padding(padding)
	if padding == nil then
		return 0, 0, 0, 0
	end
	if type(padding) == "number" then
		return padding, padding, padding, padding
	end
	if #padding == 2 then
		local horizontal = padding[1]
		local vertical = padding[2]
		return horizontal, vertical, horizontal, vertical
	end
	return padding[1], padding[2], padding[3], padding[4]
end

---@param value string | number
---@param parent_size number
---@return number
local function resolve_fixed_or_percent(value, parent_size)
	if value == nil or value == "*" then
		return 0
	end
	if type(value) == "number" then
		return value
	end
	local percent = value:match(percent_pattern)
	if percent then
		return parent_size * (tonumber(percent) / 100)
	end
	error(("[ui.Layout] Invalid size %q"):format(tostring(value)))
end

---@param size any
---@return boolean
local function is_fill(size)
	return size == nil or size == "*"
end

---@param box ui.Box
---@param x number
---@param y number
---@param width number
---@param height number
---@param layout_scale number
local function update_box(box, x, y, width, height, layout_scale)
	box:update(x, y, width, height, layout_scale)
end

---@param self ui.Layout
---@param node ui.LayoutNode
---@param seen table<string, boolean>
local function register_node(self, node, seen)
	if type(node) ~= "table" then
		error("[ui.Layout] Invalid node structure")
	end

	validate_size(node.w, "w", node)
	validate_size(node.h, "h", node)
	validate_align(node.align, node)
	validate_padding(node.padding, node)
	validate_arrange(node.arrange, node)

	if node.id ~= nil then
		if type(node.id) ~= "string" or node.id == "" then
			error("[ui.Layout] Node id must be a non-empty string")
		end
		if seen[node.id] then
			error(("[ui.Layout] Duplicate id %q"):format(node.id))
		end
		seen[node.id] = true
		self.boxes[node.id] = Box()
	end

	local children = node.children
	if children ~= nil then
		if type(children) ~= "table" then
			error(("[ui.Layout] children must be an array for node %s"):format(node.id or "<anonymous>"))
		end
		for i, child in ipairs(children) do
			if child == nil then
				error(("[ui.Layout] Invalid child at index %d for node %s"):format(i, node.id or "<anonymous>"))
			end
			register_node(self, child, seen)
		end
	end
end

---@param config ui.Layout.Config
function Layout:new(config)
	if type(config) ~= "table" then
		error("[ui.Layout] Config table is required")
	end
	if type(config.root) ~= "table" then
		error("[ui.Layout] root is required")
	end
	if config.target_height ~= nil and type(config.target_height) ~= "number" then
		error("[ui.Layout] target_height must be a number")
	end

	self.boxes = {}
	self.root = config.root
	self.target_height = config.target_height
	self.root_box = Box()

	register_node(self, self.root, {})
end

---@param self ui.Layout
---@param node ui.LayoutNode
---@param parent_box ui.Box
---@param layout_scale number
---@param forced_width number?
---@param forced_height number?
---@param forced_x number?
---@param forced_y number?
local function layout_node(self, node, parent_box, layout_scale, forced_width, forced_height, forced_x, forced_y)
	local arrange = node.arrange or "stack"
	local align = node.align or {0, 0}

	local width = forced_width or resolve_fixed_or_percent(node.w, parent_box.width)
	local height = forced_height or resolve_fixed_or_percent(node.h, parent_box.height)

	if forced_width == nil and is_fill(node.w) then
		width = parent_box.width
	end
	if forced_height == nil and is_fill(node.h) then
		height = parent_box.height
	end

	local x = forced_x
	local y = forced_y

	if x == nil then
		x = parent_box.x + (parent_box.width - width) * align[1]
	end
	if y == nil then
		y = parent_box.y + (parent_box.height - height) * align[2]
	end

	local box = node.id and self.boxes[node.id] or self.root_box
	update_box(box, x, y, width, height, layout_scale)

	local padding_left, padding_top, padding_right, padding_bottom = resolve_padding(node.padding)
	local content_x = x + padding_left
	local content_y = y + padding_top
	local content_width = math.max(0, width - padding_left - padding_right)
	local content_height = math.max(0, height - padding_top - padding_bottom)
	local content_box = {
		x = content_x,
		y = content_y,
		width = content_width,
		height = content_height,
	}

	local children = node.children
	if not children or #children == 0 then
		return
	end

	if arrange == "stack" then
		for _, child in ipairs(children) do
			layout_node(self, child, content_box, layout_scale)
		end
		return
	end

	local main_parent = arrange == "row" and content_width or content_height
	local cursor = arrange == "row" and content_x or content_y
	local main_total = 0
	local fill_count = 0

	for _, child in ipairs(children) do
		local main_size = arrange == "row"
			and resolve_fixed_or_percent(child.w, content_width)
			or resolve_fixed_or_percent(child.h, content_height)
		if is_fill(arrange == "row" and child.w or child.h) then
			fill_count = fill_count + 1
		else
			main_total = main_total + main_size
		end
	end

	local remaining = math.max(0, main_parent - main_total)
	local fill_size = fill_count > 0 and remaining / fill_count or 0

	for _, child in ipairs(children) do
		local child_align = child.align or {0, 0}
		local child_width
		local child_height
		local child_x
		local child_y

		if arrange == "row" then
			child_width = is_fill(child.w) and fill_size or resolve_fixed_or_percent(child.w, content_width)
			child_height = is_fill(child.h) and content_height or resolve_fixed_or_percent(child.h, content_height)
			child_x = cursor
			child_y = content_y + (content_height - child_height) * child_align[2]
			cursor = cursor + child_width
		else
			child_height = is_fill(child.h) and fill_size or resolve_fixed_or_percent(child.h, content_height)
			child_width = is_fill(child.w) and content_width or resolve_fixed_or_percent(child.w, content_width)
			child_x = content_x + (content_width - child_width) * child_align[1]
			child_y = cursor
			cursor = cursor + child_height
		end

		layout_node(self, child, box, layout_scale, child_width, child_height, child_x, child_y)
	end
end

---@param viewport_width number
---@param viewport_height number
---@param layout_scale number?
function Layout:update(viewport_width, viewport_height, layout_scale)
	layout_scale = layout_scale
		or (self.target_height and viewport_height / self.target_height)
		or 1
	layout_scale = layout_scale > 0 and layout_scale or 1

	local logical_width = viewport_width / layout_scale
	local logical_height = viewport_height / layout_scale
	update_box(self.root_box, 0, 0, logical_width, logical_height, layout_scale)
	layout_node(self, self.root, self.root_box, layout_scale)
end

---@param id string
---@return ui.Box
function Layout:get(id)
	local box = self.boxes[id]
	if not box then
		error(("[ui.Layout] Unknown id %q"):format(tostring(id)))
	end
	return box
end

return Layout
