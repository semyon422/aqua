local fields = require("ui.luvx.validation")

local Style = require("ui.style.Style")
local LayoutEnums = require("ui.layout.Enums")
local SizeMode = LayoutEnums.SizeMode
local Arrange = LayoutEnums.Arrange
local JustifyContent = LayoutEnums.JustifyContent
local AlignItems = LayoutEnums.AlignItems
local Pivot = LayoutEnums.Pivot

local Label = require("ui.view.Label")

local BackgroundColor = require("ui.style.Shader.BackgroundColor")
local LinearGradient = require("ui.style.Shader.LinearGradient")
local BorderRadius = require("ui.style.Shader.BorderRadius")
local Brightness = require("ui.style.Shader.Brightness")
local Contrast = require("ui.style.Shader.Contrast")
local Saturation = require("ui.style.Shader.Saturation")
local Outline = require("ui.style.Shader.Outline")

---@class core.LuvX
---@overload fun(metatable: view.Node, params: {[string]: any}, childen: view.Node[]?): nya.Node
local LuvX = {}

LuvX.layout_props = {
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
	flex_grow = function(node, value)
		node.layout_box.flex_grow = fields.flex_grow(value)
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
	end
}

LuvX.style_props = {
	---@param style table
	---@param t { x: number, y: number, radius: number, color: ui.Color }
	shadow = function(style, t)
		style.main.shadow = fields.shadow(t)
	end,

	---@param style table
	---@param t { type: "gaussian" | "kawase", radius: number}
	bd_blur = function(style, t)
		local b = fields.bd_blur(t)
		style.backdrop_props.blur = b
		style.backdrop_props.padding = b.radius * 2
	end,

	---@param style table
	---@param v number
	bd_brightness = function(style, v)
		table.insert(style.backdrop_effects, {
			layer = 10,
			effect = Brightness(fields.bd_brightness(v))
		})
	end,

	---@param style table
	---@param v number
	bd_contrast = function(style, v)
		table.insert(style.backdrop_effects, {
			layer = 5,
			effect = Contrast(fields.bd_contrast(v))
		})
	end,

	---@param style table
	---@param v number
	bd_saturation = function(style, v)
		table.insert(style.backdrop_effects, {
			layer = 0,
			effect = Saturation(fields.bd_saturation(v))
		})
	end,

	---@param style table
	---@param v number
	brightness = function(style, v)
		table.insert(style.content_effects, {
			layer = 10,
			effect = Brightness(fields.brightness(v))
		})
	end,

	---@param style table
	---@param v number
	contrast = function(style, v)
		table.insert(style.content_effects, {
			layer = 5,
			effect = Contrast(fields.contrast(v))
		})
	end,

	---@param style table
	---@param v number
	saturation = function(style, v)
		table.insert(style.content_effects, {
			layer = 0,
			effect = Saturation(fields.saturation(v))
		})
	end,

	---@param style table
	---@param color ui.Color
	background_color = function(style, color)
		table.insert(style.content_effects, {
			layer = 0,
			effect = BackgroundColor(fields.background_color(color))
		})
	end,

	---@param style table
	---@param t { colors: table<{ t: number, color: ui.Color}>, angle: number? }
	linear_gradient = function(style, t)
		t = fields.linear_gradient(t)
		table.insert(style.content_effects, {
			layer = 10,
			effect = LinearGradient(t.colors[1].color, t.colors[2].color, t.angle)
		})
	end,

	---@param style table
	---@param t table<number> | number
	border_radius = function(style, t)
		style.main.border_radius = fields.border_radius(t)
		table.insert(style.content_effects, {
			layer = 10000,
			effect = BorderRadius()
		})
	end,

	---@param style table
	---@param t table<number> | number
	--- TODO: Remove this
	bd_border_radius = function(style, t)
		style.main.border_radius = fields.border_radius(t)
		table.insert(style.backdrop_effects, {
			layer = 10000,
			effect = BorderRadius()
		})
	end,

	---@param style table
	---@param t { thickness: number, color: ui.Color }
	border = function(style, t)
		t = fields.border(t)
		table.insert(style.content_effects, {
			layer = 90000,
			effect = Outline(t.color, t.thickness)
		})
	end,

	---@param style table
	---@param color table<number>
	color = function(style, color)
		style.content_props.color = fields.color(color)
	end,

	---@param style table
	---@param alpha number
	alpha = function(style, alpha)
		style.content_props.alpha = fields.alpha(alpha)
	end,

	---@param style table
	---@param blend_mode string
	blend_mode = function(style, blend_mode)
		style.content_props.blend_mode = fields.blend_mode(blend_mode)
	end,

	---@param style table
	---@param blend_mode_alpha string
	blend_mode_alpha = function(style, blend_mode_alpha)
		style.content_props.blend_mode_alpha = fields.blend_mode_alpha(blend_mode_alpha)
	end,

	---@param node view.Node
	---@param clip boolean
	clip = function(node, clip)
		error("Not implemented")
		--style.content_props.clip = fields.clip(clip)
	end
}

LuvX.node_props = {
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
}

---@param metatable view.Node
---@param params ({[string]: any}?) | ({[string]: any}[]?)
---@param children view.Node[]?
---@return view.Node
function LuvX.createElement(metatable, params, children)
	if not params then
		local instance = metatable()
		if children then
			for _, child in ipairs(children) do
				instance:add(child)
			end
		end
		return instance
	end

	if #params > 0 then
		local mixed = {}

		for _, t in ipairs(params) do
			for k, v in pairs(t) do
				mixed[k] = v
			end
		end

		params = mixed
	end

	---@cast params {[string]: any}

	local instance = metatable()

	local style_table = {
		main = {},
		content_props = {},
		content_effects = {},
		backdrop_props = {},
		backdrop_effects = {}
	}

	local leftovers = {}

	for k, v in pairs(params) do
		if LuvX.layout_props[k] then
			LuvX.layout_props[k](instance, v)
		elseif LuvX.style_props[k] then
			LuvX.style_props[k](style_table, v)
		elseif LuvX.node_props[k] then
			LuvX.node_props[k](instance, v)
		else
			leftovers[k] = v
		end
	end

	instance:init(leftovers)

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
		return t.createElement(...)
	end
}

setmetatable(LuvX, mt) ---@diagnostic disable-line

return LuvX
