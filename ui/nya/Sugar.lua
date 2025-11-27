local Style = require("ui.style.Style")
local LayoutEnums = require("ui.layout.Enums")
local SizeMode = LayoutEnums.SizeMode
local Arrange = LayoutEnums.Arrange
local JustifyContent = LayoutEnums.JustifyContent
local AlignItems = LayoutEnums.AlignItems
local Pivot = LayoutEnums.Pivot

local BackgroundColor = require("ui.style.Shader.BackgroundColor")
local LinearGradient = require("ui.style.Shader.LinearGradient")
local BorderRadius = require("ui.style.Shader.BorderRadius")

local pivots = {
	top_left = Pivot.TopLeft,
	top_center = Pivot.TopCenter,
	top_right = Pivot.TopRight,
	center_left = Pivot.CenterLeft,
	center = Pivot.Center,
	center_right = Pivot.CenterRight,
	bottom_left = Pivot.BottomLeft,
	bottom_center = Pivot.BottomCenter,
	bottom_right = Pivot.BottomRight,
}

---@class nya.Sugar
---@overload fun(metatable: nya.Node, params: {[string]: any}, childen: nya.Node[]?): nya.Node
local Sugar = {}

---@param t table
---@param _type type
---@param size number
local function is_array_of_type(t, _type, size)
	if type(t) ~= "table" then
		return false
	end
	if #t ~= size then
		return false
	end
	for _, v in ipairs(t) do
		if type(v) ~= _type then
			return false
		end
	end
	return true
end

Sugar.layout_props = {
	---@param node nya.Node
	---@param size number | string
	width = function(node, size)
		local axis = node.layout_box.x

		if type(size) == "string" then
			if size == "auto" then
				axis.size = SizeMode.Auto
			elseif size == "fit" then
				axis.size = SizeMode.Fit
			else
				assert("Expected 'auto', 'fit' or a number for width")
			end
			return
		end

		assert(type(size) == "number", "Expected width to be a number")
		axis.preferred_size = size
		axis.mode = SizeMode.Fixed
	end,

	---@param node nya.Node
	---@param size number | string
	height = function(node, size)
		local axis = node.layout_box.y

		if type(size) == "string" then
			if size == "auto" then
				axis.size = SizeMode.Auto
			elseif size == "fit" then
				axis.size = SizeMode.Fit
			else
				error("Expected 'auto', 'fit' or a number for height")
			end
			return
		end

		assert(type(size) == "number", "Expected height to be a number")
		axis.preferred_size = size
		axis.mode = SizeMode.Fixed
	end,

	---@param node nya.Node
	---@param size number
	min_width = function(node, size)
		assert(type(size) == "number", "Expected min_width to be a number")
		node.layout_box.x.min_size = math.max(size, 0)
	end,

	---@param node nya.Node
	---@param size number
	min_height = function(node, size)
		assert(type(size) == "number", "Expected min_height to be a number")
		node.layout_box.y.min_size = math.max(size, 0)
	end,

	---@param node nya.Node
	---@param size number
	max_width = function(node, size)
		assert(type(size) == "number", "Expected max_width to be a number")
		node.layout_box.x.max_size = math.max(size, 0)
	end,

	---@param node nya.Node
	---@param size number
	max_height = function(node, size)
		assert(type(size) == "number", "Expected max_height to be a number")
		node.layout_box.y.max_size = math.max(size, 0)
	end,

	---@param node nya.Node
	---@param padding table<number> | number
	padding = function(node, padding)
		local box = node.layout_box

		if type(padding) == "table" then
			assert(
				is_array_of_type(padding, "number", 4),
				"Expected padding to be an array of 4 numbers"
			)
			box.x.padding_start = padding[1]
			box.y.padding_start = padding[2]
			box.y.padding_end = padding[3]
			box.x.padding_end = padding[4]
			return
		end

		assert(type(padding) == "number", "Expected padding to be a table<number> or a number")
		box.x.padding_start = padding
		box.y.padding_start = padding
		box.y.padding_end = padding
		box.x.padding_end = padding
	end,

	---@param node nya.Node
	---@param arrange string
	arrange = function(node, arrange)
		local box = node.layout_box

		if arrange == "absolute" then
			box.arrange = Arrange.Absolute
		elseif arrange == "flow_h" then
			box.arrange = Arrange.FlowH
		elseif arrange == "flow_v" then
			box.arrange = Arrange.FlowV
		else
			error("Expected 'absolute', 'flow_h' or 'flow_v' for arrange")
		end
	end,

	---@param node nya.Node
	---@param justify string
	justify_content = function(node, justify)
		local box = node.layout_box

		if justify == "start" then
			box.justify_content = JustifyContent.Start
		elseif justify == "center" then
			box.justify_content = JustifyContent.Center
		elseif justify == "end" then
			box.justify_content = JustifyContent.End
		elseif justify == "space_between" then
			box.justify_content = JustifyContent.SpaceBetween
		else
			error("Expected 'start', 'center', 'end' or 'space_between' for justify_content")
		end
	end,

	---@param node nya.Node
	---@param align string
	align_items = function(node, align)
		local box = node.layout_box

		if align == "start" then
			box.align_items = AlignItems.Start
		elseif align == "center" then
			box.align_items = AlignItems.Center
		elseif align == "end" then
			box.align_items = AlignItems.End
		elseif align == "stretch" then
			box.align_items = AlignItems.Stretch
		else
			error("Expected 'start', 'center', 'end' or 'stretch' for align_items")
		end
	end,

	---@param node nya.Node
	---@param align string
	align_self = function(node, align)
		local box = node.layout_box

		if align == "start" then
			box.align_self = AlignItems.Start
		elseif align == "center" then
			box.align_self = AlignItems.Center
		elseif align == "end" then
			box.align_self = AlignItems.End
		elseif align == "stretch" then
			box.align_self = AlignItems.Stretch
		else
			error("Expected 'start', 'center', 'end' or 'stretch' for align_self")
		end
	end,

	---@param node nya.Node
	---@param value number
	flex_grow = function(node, value)
		assert(type(value) == "number", "Expected flex_grow to be a number")
		node.layout_box.flex_grow = value
	end,

	---@param node nya.Node
	---@param value number
	child_gap = function(node, value)
		assert(type(value) == "number", "Expected child_gap to be a number")
		node.layout_box.child_gap = value
	end,

	---@param node nya.Node
	---@param pivot ui.Pivot | string
	origin = function(node, pivot)
		if type(pivot) == "string" then
			local p = pivots[pivot]
			if not p then
				error("Invalid origin pivot name")
			end
			node.layout_box.origin = p
			return
		end
		assert(pivot.x and type(pivot.x), "Expected origin.x to be a number")
		assert(pivot.y and type(pivot.y), "Expected origin.y to be a number")
		node.layout_box.origin = pivot
	end,

	---@param node nya.Node
	---@param pivot ui.Pivot | string
	anchor = function(node, pivot)
		if type(pivot) == "string" then
			local p = pivots[pivot]
			if not p then
				error("Invalid anchor pivot name")
			end
			node.layout_box.anchor = p
			return
		end
		assert(pivot.x and type(pivot.x), "Expected anchor.x to be a number")
		assert(pivot.y and type(pivot.y), "Expected anchor.y to be a number")
		node.layout_box.anchor = pivot
	end,

	---@param node nya.Node
	---@param pivot ui.Pivot | string
	pivot = function(node, pivot)
		if type(pivot) == "string" then
			local p = pivots[pivot]
			if not p then
				error("Invalid pivot name")
			end
			node.layout_box.origin = p
			node.layout_box.anchor = p
			return
		end
		assert(pivot.x and type(pivot.x), "Expected pivot.x to be a number")
		assert(pivot.y and type(pivot.y), "Expected pivot.y to be a number")
		node.layout_box.origin = pivot
		node.layout_box.anchor = pivot
	end
}

Sugar.style_props = {
	---@param style table
	---@param t { x: number, y: number, radius: number, color: ui.Color }
	shadow = function(style, t)
		local x = t.x or 0
		local y = t.y or 0
		local radius = t.radius or 0
		local color = t.color or { 0, 0, 0, 0.1 }
		assert(type(x) == "number", "Expected shadow.x to be a number")
		assert(type(y) == "number", "Expected shadow.y to be a number")
		assert(type(radius) == "number", "Expected shadow.radius to be a number")
		assert(
			is_array_of_type(color, "number", 4),
			"Expected shadow.color to be an array of 4 numbers"
		)
		style.main.shadow = { x = x, y = y, radius = radius, color = color }
	end,

	---@param style table
	---@param t { type: "gaussian" | "kawase", radius: number}
	bd_blur = function(style, t)
		assert(type(t) == "table", "Expected bd_blur to be a table")
		assert(type(t.type) == "string", "Expected bd_blur.type to be a string")
		assert(type(t.radius) == "number", "Expected bd_blur.radius to be a nuber")
		style.backdrop_props.blur = t
		style.backdrop_props.padding = t.radius * 2
	end,

	---@param style table
	---@param color ui.Color
	background_color = function(style, color)
		assert(
			is_array_of_type(color, "number", 4),
			"Expected background_color to be an array of 4 numbers"
		)
		table.insert(style.content_effects, {
			layer = 0,
			effect = BackgroundColor(color)
		})
	end,

	---@param style table
	---@param t { color1: ui.Color, color2: ui.Color, angle: number? }
	linear_gradient = function(style, t)
		assert(type(t) == "table", "Expected linear_gradient to be a table")
		assert(
			is_array_of_type(t.color1, "number", 4),
			"Expected linear_gradient.color1 to be an array of 4 numbers"
		)
		assert(
			is_array_of_type(t.color2, "number", 4),
			"Expected linear_gradient.color2 to be an array of 4 numbers"
		)
		local angle = t.angle or 0
		assert(type(angle) == "number", "Expected angle to be a number")

		table.insert(style.content_effects, {
			layer = 10,
			effect = LinearGradient(t.color1, t.color2, angle)
		})
	end,

	---@param style table
	---@param t table<number> | number
	border_radius = function(style, t)
		if type(t) == "table" then
			assert(
				is_array_of_type(t, "number", 4),
				"Expected border_radius to be an array of 4 numbers or a number"
			)
			style.main.border_radius = t
		else
			assert(type(t) == "number", "Expected border_radius to be a number or a table")
			style.main.border_radius = { t, t, t, t }
		end

		table.insert(style.content_effects, {
			layer = 10000,
			effect = BorderRadius()
		})
	end,

	---@param style table
	---@param color table<number>
	color = function(style, color)
		assert(
			is_array_of_type(color, "number"),
			"Expected color to be an array of 4 numbers"
		)
		style.content_props.color = color
	end,

	---@param style table
	---@param alpha number
	alpha = function(style, alpha)
		assert(type(alpha) == "number", "Expected number to be a number")
		style.content_props.alpha = alpha
	end
}

Sugar.node_props = {
	---@param node nya.Node
	---@param id string
	id = function(node, id)
		assert(type(id) == "string", "Expected id to be a string")
		node.id = id
	end,

	---@param node nya.Node
	---@param t table
	transform = function(node, t)
		assert(type(t) == "table")
		local tf = node.transform
		local x = t.x or 0
		local y = t.y or 0
		local angle = t.angle or 0
		local scale_x = t.sx or 0
		local scale_y = t.sy or 0
		local shear_x = t.kx or 0
		local shear_y = t.ky or 0
		assert(type(x) == "number", "Expected transform.x to be a number")
		assert(type(y) == "number", "Expected transform.u to be a number")
		assert(type(angle) == "number", "Expected transform.angle to be a number")
		assert(type(scale_x) == "number", "Expected transform.sx to be a number")
		assert(type(scale_y) == "number", "Expected transform.sy to be a number")
		assert(type(shear_x) == "number", "Expected transform.kx to be a number")
		assert(type(shear_y) == "number", "Expected transform.ky to be a number")
		tf.x, tf.y = x, y
		tf.angle = angle
		tf.scale_x, tf.scale_y = scale_x, scale_y
		tf.shear_x, tf.shear_y = shear_x, shear_y
		tf.invalidated = true
	end,

	---@param node nya.Node
	---@param z number
	z = function(node, z)
		assert(type(z) == "number", "Expected z to be a number")
		node.z = z
	end
}

---@param metatable nya.Node
---@param params {[string]: any}?
---@param children nya.Node[]?
---@return nya.Node
function Sugar.create(metatable, params, children)
	local instance = metatable()

	if not params then
		if children then
			for _, child in ipairs(children) do
				instance:add(child)
			end
		end
		return instance
	end

	local style_table = {
		main = {},
		content_props = {},
		content_effects = {},
		backdrop_props = {},
		backdrop_effects = {}
	}

	for k, v in pairs(params) do
		if Sugar.layout_props[k] then
			Sugar.layout_props[k](instance, v)
		elseif Sugar.style_props[k] then
			Sugar.style_props[k](style_table, v)
		elseif Sugar.node_props[k] then
			Sugar.node_props[k](instance, v)
		end
	end

	local has_styles = false
	local has_backdrop = false
	local has_content = false
	local content = { effects = {} }
	local backdrop = { effects = {} }

	if #style_table.backdrop_effects ~= 0 then
		table.sort(style_table.backdrop_effects, function(a, b)
			return a.layer < b.layer
		end)
		for _, v in ipairs(style_table.backdrop_effects) do
			table.insert(backdrop.effects, v.effect)
		end
		has_styles = true
		has_backdrop = true
	end

	if #style_table.content_effects ~= 0 then
		table.sort(style_table.content_effects, function(a, b)
			return a.layer < b.layer
		end)
		for _, v in ipairs(style_table.content_effects) do
			table.insert(content.effects, v.effect)
		end
		has_styles = true
		has_content = true
	end

	if next(style_table.backdrop_props) then
		for k, v in pairs(style_table.backdrop_props) do
			backdrop[k] = v
		end
		has_styles = true
		has_backdrop = true
	end

	if next(style_table.content_props) then
		for k, v in pairs(style_table.content_props) do
			content[k] = v
		end
		has_styles = true
		has_content = true
	end

	if has_styles then
		local style = style_table.main

		if has_content then
			style.content = content
		end

		if has_backdrop then
			style.backdrop = backdrop
		end

		instance.style = Style(style)
	end

	if children then
		for _, child in ipairs(children) do
			instance:add(child)
		end
	end

	return instance
end

local mt = {
	__call = function(t, ...)
		return t.create(...)
	end
}

setmetatable(Sugar, mt)

local implemented = {
	-- Layout
	width = 0,             -- "auto" | "fit" | number
	height = 0,            -- "auto" | "fit" | number
	min_width = 0,         -- number
	min_height = 0,        -- number
	max_width = math.huge, -- number
	max_height = math.huge, -- number
	padding = 0,           -- number | 4 numbers
	arrange = "absolute",  -- "flow_h" |  "flow_v" | "absolute"
	justify_content = "left", -- "start" | "center" | "end" | "space_between"
	align_items = "start", -- "start" | "center" | "end" | "stretch"
	align_self = "start",  -- "start" | "center" | "end" | "stretch"
	flex_grow = 0,         -- number
	child_gap = 0,         -- number
	origin = "left",       -- {x: number, y: number} or 9 positions as strings
	anchor = "left",       -- {x: number, y: number} or 9 positions as strings

	-- Tree
	z = 0, -- number

	-- Transform
	transform = { x = 0, y = 0, angle = 0, sx = 1, sy = 1, ox = 0, oy = 0, kx = 0, ky = 0 },

	-- Style
	shadow = { x = 0, y = 0, radius = 0, color = { 1, 1, 1, 1 } },

	-- bd means backdrop
	bd_blur = { type = "gaussian", radius = 4 },
	bd_brightness = 1,              -- number
	bd_contrast = 1,                -- number
	bd_saturation = 1,              -- number

	background_color = { 1, 1, 1, 1 }, -- 4 numbers
	linear_gradient = { color1 = { 1, 0, 0, 1 }, color2 = { 0, 1, 0, 1 }, angle = 0 },
	brightness = 1,                 -- number
	contrast = 1,                   -- number
	saturation = 1,
	border_radius = 0,              -- number | 4 numbers
	border = { { 1, 1, 1, 1 }, thickness = 0 },

	-- Only affects the content
	color = { 1, 1, 1, 1 },          -- 4 numbers
	alpha = 1,                       -- number
	blend_mode = "alpha",            -- any love blend mode
	blend_mode_alpha = "alphamultiply", -- any love blend mode alpha
	clip = false                     -- stencil
}

return Sugar
