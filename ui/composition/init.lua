local Box = require("ui.Box")

local percent_pattern = "^(%-?%d+%.?%d*)%%$"

---@alias ui.composition.Padding number|[number, number]|[number, number, number, number]
---@alias ui.composition.SizeSpec {kind: "fill"}|{kind: "fixed", value: number}|{kind: "percent", value: number}
---@alias ui.composition.Child ui.View|ui.composition.Node
---@alias ui.composition.MeasuredItem ui.composition.MeasuredView|ui.composition.MeasuredNode

---@class ui.composition.MeasuredView
---@field kind "view"
---@field view ui.View
---@field width number
---@field height number

---@class ui.composition.MeasuredNode
---@field kind "node"
---@field node ui.composition.Node
---@field width number
---@field height number
---@field measured ui.composition.MeasuredLayout

---@class ui.composition.MeasuredLayout
---@field width number
---@field height number
---@field inner_width number
---@field inner_height number
---@field padding_left number
---@field padding_top number
---@field children ui.composition.MeasuredItem[]
---@field content_width number?
---@field content_height number?

---@class ui.composition.Props
---@field w number|string?
---@field h number|string?
---@field pivot ui.ViewPoint?
---@field padding ui.composition.Padding?
---@field [integer] ui.composition.Child

---@class ui.composition.FlowProps: ui.composition.Props
---@field gap number?
---@field align ui.ViewPoint?

---@alias ui.composition.StackProps ui.composition.Props
---@alias ui.composition.VerticalProps ui.composition.FlowProps
---@alias ui.composition.HorizontalProps ui.composition.FlowProps

---@class ui.composition.Node
---@overload fun(x: number, y: number, available_w: number, available_h: number, layout_scale: number?): ui.View[]
---@field composition_node true
---@field kind "stack"|"vertical"|"horizontal"
---@field props ui.composition.Props|ui.composition.FlowProps
---@field children ui.composition.Child[]
---@field box ui.Box
---@field sizes {[ "w" | "h" ]: ui.composition.SizeSpec}
---@field subtree_nodes {[ui.composition.Node]: true}
---@field subtree_views {[ui.View]: true}
local Node = {}
Node.__index = Node

local function is_node(value)
	return type(value) == "table" and value.composition_node == true
end

local function is_view(value)
	return type(value) == "table"
		and value.transform ~= nil
		and type(value.refresh) == "function"
end

---@param value any
---@param field string
---@param kind string
---@return ui.composition.SizeSpec
local function parse_size(value, field, kind)
	if value == nil or value == "*" then
		return {kind = "fill"}
	end
	if type(value) == "number" then
		---@cast value number
		return {kind = "fixed", value = value}
	end
	if type(value) == "string" then
		---@cast value string
		local percent = value:match(percent_pattern)
		if percent then
			return {kind = "percent", value = tonumber(percent) / 100}
		end
	end
	error(("[ui.composition.%s] Invalid %s %q"):format(kind, field, tostring(value)))
end

---@param value any
---@param field string
---@param kind string
local function validate_point(value, field, kind)
	if value == nil then
		return
	end
	if type(value) ~= "table" or type(value[1]) ~= "number" or type(value[2]) ~= "number" then
		error(("[ui.composition.%s] Invalid %s"):format(kind, field))
	end
end

---@param props ui.composition.Props|ui.composition.FlowProps
---@param kind string
---@return {[ "w" | "h" ]: ui.composition.SizeSpec}
local function validate_props(props, kind)
	if type(props) ~= "table" then
		error(("[ui.composition.%s] props table is required"):format(kind))
	end

	local sizes = {
		w = parse_size(props.w, "w", kind),
		h = parse_size(props.h, "h", kind),
	}
	validate_point(props.pivot, "pivot", kind)
	validate_point(props.align, "align", kind)

	if props.gap ~= nil and type(props.gap) ~= "number" then
		error(("[ui.composition.%s] Invalid gap"):format(kind))
	end
	if props.padding ~= nil then
		local padding = props.padding
		if type(padding) == "number" then
			return sizes
		end
		if type(padding) ~= "table" then
			error(("[ui.composition.%s] Invalid padding"):format(kind))
		end
		local count = #padding
		if count ~= 2 and count ~= 4 then
			error(("[ui.composition.%s] Invalid padding"):format(kind))
		end
		for i = 1, count do
			if type(padding[i]) ~= "number" then
				error(("[ui.composition.%s] Invalid padding"):format(kind))
			end
		end
	end

	return sizes
end

---@param padding ui.composition.Padding?
---@return number, number, number, number
local function resolve_padding(padding)
	if padding == nil then
		return 0, 0, 0, 0
	end
	if type(padding) == "number" then
		return padding, padding, padding, padding
	end
	if #padding == 2 then
		return padding[1], padding[2], padding[1], padding[2]
	end
	return padding[1], padding[2], padding[3], padding[4]
end

---@param spec ui.composition.SizeSpec
---@param available number?
---@param field string
---@param kind string
local function resolve_size(spec, available, field, kind)
	if spec.kind == "fill" then
		assert(available ~= nil, ("[ui.composition.%s] %s requires explicit parent size"):format(kind, field))
		return available
	end
	if spec.kind == "fixed" then
		return spec.value
	end
	assert(available ~= nil, ("[ui.composition.%s] %s percent requires explicit parent size"):format(kind, field))
	return available * spec.value
end

---@param view ui.View
---@return ui.Box
local function ensure_view_box(view)
	if not view.box then
		view.box = Box()
	end
	return view.box
end

---@param item ui.composition.Child
---@param available_w number?
---@param available_h number?
---@return ui.composition.MeasuredItem
local function measure_item(item, available_w, available_h)
	if is_node(item) then
		local measured = item:measure(available_w, available_h)
		return {
			kind = "node",
			node = item,
			width = measured.width,
			height = measured.height,
			measured = measured,
		}
	end

	---@cast item ui.View
	local width ---@type number?
	if item.width_percent ~= nil then
		assert(available_w ~= nil, "[ui.composition] Fit containers do not support width_percent children")
		width = available_w * item.width_percent
	else
		width = item.width
	end

	local height ---@type number?
	if item.height_percent ~= nil then
		assert(available_h ~= nil, "[ui.composition] Fit containers do not support height_percent children")
		height = available_h * item.height_percent
	else
		height = item.height
	end

	assert(type(width) == "number", "[ui.composition] View width must be a number")
	assert(type(height) == "number", "[ui.composition] View height must be a number")

	return {
		kind = "view",
		view = item,
		width = width,
		height = height,
	}
end

---@param item ui.composition.Child
---@param field "w"|"h"
---@return boolean
local function is_fill_child(item, field)
	if not is_node(item) then
		return false
	end
	return item.sizes[field].kind == "fill"
end

---@param kind "stack"|"vertical"|"horizontal"
---@param props ui.composition.Props|ui.composition.FlowProps
---@return ui.composition.Node
local function new_node(kind, props)
	local sizes = validate_props(props, kind)

	local children = {} ---@type ui.composition.Child[]
	for i, child in ipairs(props) do
		if not is_node(child) and not is_view(child) then
			error(("[ui.composition.%s] Invalid child at index %d"):format(kind, i))
		end
		children[i] = child
	end

	local seen_nodes = {} ---@type {[ui.composition.Node]: boolean}
	local seen_views = {} ---@type {[ui.View]: boolean}

	local node = setmetatable({
		composition_node = true,
		kind = kind,
		props = props,
		children = children,
		box = Box(),
		sizes = sizes,
	}, Node)

	seen_nodes[node] = true

	for _, child in ipairs(children) do
		if is_node(child) then
			---@cast child ui.composition.Node
			for nested_node in pairs(child.subtree_nodes) do
				if seen_nodes[nested_node] then
					error(("[ui.composition.%s] Composition node reused in the same tree"):format(kind))
				end
				seen_nodes[nested_node] = true
			end
			for nested_view in pairs(child.subtree_views) do
				if seen_views[nested_view] then
					error(("[ui.composition.%s] View reused in the same tree"):format(kind))
				end
				seen_views[nested_view] = true
			end
		else
			---@cast child ui.View
			if seen_views[child] then
				error(("[ui.composition.%s] View reused in the same tree"):format(kind))
			end
			seen_views[child] = true
		end
	end

	node.subtree_nodes = seen_nodes
	node.subtree_views = seen_views
	return node
end

---@param available_w number?
---@param available_h number?
---@return ui.composition.MeasuredLayout
function Node:measure(available_w, available_h)
	local props = self.props
	local gap = props.gap or 0
	local padding_left, padding_top, padding_right, padding_bottom = resolve_padding(props.padding)

	if self.kind == "stack" then
		local width = resolve_size(self.sizes.w, available_w, "w", self.kind)
		local height = resolve_size(self.sizes.h, available_h, "h", self.kind)
		local inner_width = math.max(0, width - padding_left - padding_right)
		local inner_height = math.max(0, height - padding_top - padding_bottom)
		local children = {} ---@type ui.composition.MeasuredItem[]
		for i, child in ipairs(self.children) do
			children[i] = measure_item(child, inner_width, inner_height)
		end
		return {
			width = width,
			height = height,
			inner_width = inner_width,
			inner_height = inner_height,
			padding_left = padding_left,
			padding_top = padding_top,
			children = children,
		}
	end

	local explicit_w = props.w ~= nil and resolve_size(self.sizes.w, available_w, "w", self.kind) or nil
	local explicit_h = props.h ~= nil and resolve_size(self.sizes.h, available_h, "h", self.kind) or nil

	local child_available_w = explicit_w and math.max(0, explicit_w - padding_left - padding_right) or nil
	local child_available_h = explicit_h and math.max(0, explicit_h - padding_top - padding_bottom) or nil
	local content_width = 0
	local content_height = 0
	local children = {} ---@type ui.composition.MeasuredItem[]

	if self.kind == "horizontal" and child_available_w ~= nil then
		local fixed_width = 0
		local fill_count = 0
		local fixed_children = {} ---@type ui.composition.MeasuredItem[]

		for i, child in ipairs(self.children) do
			if is_fill_child(child, "w") then
				fill_count = fill_count + 1
			else
				local measured = measure_item(child, child_available_w, child_available_h)
				fixed_children[i] = measured
				fixed_width = fixed_width + measured.width
			end
		end

		local total_gap = #self.children > 1 and gap * (#self.children - 1) or 0
		local remaining_width = math.max(0, child_available_w - fixed_width - total_gap)
		local fill_width = fill_count > 0 and remaining_width / fill_count or 0

		for i, child in ipairs(self.children) do
			local measured = fixed_children[i]
			if is_fill_child(child, "w") then
				measured = measure_item(child, fill_width, child_available_h)
			end
			children[i] = measured
			content_width = content_width + measured.width
			content_height = math.max(content_height, measured.height)
		end
	elseif self.kind == "vertical" and child_available_h ~= nil then
		local fixed_height = 0
		local fill_count = 0
		local fixed_children = {} ---@type ui.composition.MeasuredItem[]

		for i, child in ipairs(self.children) do
			if is_fill_child(child, "h") then
				fill_count = fill_count + 1
			else
				local measured = measure_item(child, child_available_w, child_available_h)
				fixed_children[i] = measured
				fixed_height = fixed_height + measured.height
			end
		end

		local total_gap = #self.children > 1 and gap * (#self.children - 1) or 0
		local remaining_height = math.max(0, child_available_h - fixed_height - total_gap)
		local fill_height = fill_count > 0 and remaining_height / fill_count or 0

		for i, child in ipairs(self.children) do
			local measured = fixed_children[i]
			if is_fill_child(child, "h") then
				measured = measure_item(child, child_available_w, fill_height)
			end
			children[i] = measured
			content_width = math.max(content_width, measured.width)
			content_height = content_height + measured.height
		end
	else
		for i, child in ipairs(self.children) do
			local measured = measure_item(child, child_available_w, child_available_h)
			children[i] = measured

			if self.kind == "vertical" then
				content_width = math.max(content_width, measured.width)
				content_height = content_height + measured.height
			else
				content_width = content_width + measured.width
				content_height = math.max(content_height, measured.height)
			end
		end
	end

	if #children > 1 then
		if self.kind == "vertical" then
			content_height = content_height + gap * (#children - 1)
		else
			content_width = content_width + gap * (#children - 1)
		end
	end

	return {
		width = explicit_w or (content_width + padding_left + padding_right),
		height = explicit_h or (content_height + padding_top + padding_bottom),
		content_width = content_width,
		content_height = content_height,
		inner_width = explicit_w and math.max(0, explicit_w - padding_left - padding_right) or content_width,
		inner_height = explicit_h and math.max(0, explicit_h - padding_top - padding_bottom) or content_height,
		padding_left = padding_left,
		padding_top = padding_top,
		children = children,
	}
end

---@param child ui.composition.Child
---@param measured ui.composition.MeasuredItem
---@param x number
---@param y number
---@param width number
---@param height number
---@param layout_scale number
---@param views ui.View[]
local function collect_child(child, measured, x, y, width, height, layout_scale, views)
	if is_node(child) then
		child:collect(measured.measured, x, y, layout_scale, views)
		return
	end

	---@cast child ui.View
	local box = ensure_view_box(child)
	box:update(x, y, width, height, layout_scale)
	table.insert(views, child)
end

---@param measured ui.composition.MeasuredLayout
---@param x number
---@param y number
---@param layout_scale number
---@param views ui.View[]
function Node:collect(measured, x, y, layout_scale, views)
	local props = self.props
	local width = measured.width
	local height = measured.height
	self.box:update(x, y, width, height, layout_scale)

	if self.kind == "stack" then
		local inner_x = x + (measured.padding_left or 0)
		local inner_y = y + (measured.padding_top or 0)
		local inner_width = measured.inner_width or width
		local inner_height = measured.inner_height or height
		for i, child in ipairs(self.children) do
			local child_measured = measured.children[i]
			if is_node(child) then
				local pivot = child.props.pivot or {0, 0}
				local child_x = inner_x + inner_width * pivot[1] - child_measured.width * pivot[1]
				local child_y = inner_y + inner_height * pivot[2] - child_measured.height * pivot[2]
				collect_child(child, child_measured, child_x, child_y, child_measured.width, child_measured.height, layout_scale, views)
			else
				collect_child(child, child_measured, inner_x, inner_y, inner_width, inner_height, layout_scale, views)
			end
		end
		return
	end

	local gap = props.gap or 0
	local align = props.align or {0, 0}
	local main_align, cross_align = align[1], align[2]
	local inner_x = x + (measured.padding_left or 0)
	local inner_y = y + (measured.padding_top or 0)
	local inner_width = measured.inner_width or width
	local inner_height = measured.inner_height or height

	if self.kind == "vertical" then
		local cursor_y = inner_y + (inner_height - measured.content_height) * main_align
		for i, child in ipairs(self.children) do
			local child_measured = measured.children[i]
			local child_x = inner_x + (inner_width - child_measured.width) * cross_align
			collect_child(child, child_measured, child_x, cursor_y, child_measured.width, child_measured.height, layout_scale, views)
			cursor_y = cursor_y + child_measured.height ---@type number
			if i < #self.children then
				cursor_y = cursor_y + gap
			end
		end
		return
	end

	local cursor_x = inner_x + (inner_width - measured.content_width) * main_align
	for i, child in ipairs(self.children) do
		local child_measured = measured.children[i]
		local child_y = inner_y + (inner_height - child_measured.height) * cross_align
		collect_child(child, child_measured, cursor_x, child_y, child_measured.width, child_measured.height, layout_scale, views)
		cursor_x = cursor_x + child_measured.width ---@type number
		if i < #self.children then
			cursor_x = cursor_x + gap
		end
	end
end

---@param x number
---@param y number
---@param available_w number
---@param available_h number
---@param layout_scale number?
---@return ui.View[]
function Node:layout(x, y, available_w, available_h, layout_scale)
	assert(type(x) == "number", "[ui.composition] x must be a number")
	assert(type(y) == "number", "[ui.composition] y must be a number")
	assert(type(available_w) == "number", "[ui.composition] available_w must be a number")
	assert(type(available_h) == "number", "[ui.composition] available_h must be a number")

	local measured = self:measure(available_w, available_h)
	local views = {} ---@type ui.View[]
	self:collect(measured, x, y, layout_scale or 1, views)
	return views
end

Node.__call = Node.layout

local composition = {}

---@param props ui.composition.StackProps
---@return ui.composition.Node
function composition.Stack(props)
	return new_node("stack", props)
end

---@param props ui.composition.VerticalProps
---@return ui.composition.Node
function composition.Vertical(props)
	return new_node("vertical", props)
end

---@param props ui.composition.HorizontalProps
---@return ui.composition.Node
function composition.Horizontal(props)
	return new_node("horizontal", props)
end

return composition
