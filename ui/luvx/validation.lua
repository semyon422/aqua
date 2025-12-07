local LayoutEnums = require("ui.layout.Enums")
local SizeMode = LayoutEnums.SizeMode
local Arrange = LayoutEnums.Arrange
local JustifyContent = LayoutEnums.JustifyContent
local AlignItems = LayoutEnums.AlignItems
local Pivot = LayoutEnums.Pivot

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

local default_color = { 1, 0, 1, 1 }

-- TODO: Developer mode (Errors crash the game)
-- TODO: No validation mode (For PCs worse than potato)

---@generic T
---@param default_value T
---@return T
local errmsg = function(default_value, err)
	io.stderr:write(debug.traceback(err))
	return default_value
end

---@generic T
---@param value T
---@param default_value T
---@param _type type
---@param err string
---@return T
local asrt_type = function(value, default_value, _type, err)
	if type(value) == _type then
		return value
	end

	io.stderr:write(debug.traceback(err))
	return default_value
end

---@generic T
---@param t table<T>
---@param _type type
---@param table_size number
---@param err string
---@return T
local function is_array_of_type(t, _type, table_size, err)
	if type(t) ~= "table" then
		io.stderr:write(debug.traceback(err))
		return false
	end
	if #t ~= table_size then
		io.stderr:write(debug.traceback(err))
		return false
	end
	for _, v in ipairs(t) do
		if type(v) ~= _type then
			io.stderr:write(debug.traceback(err))
			return false
		end
	end
	return t
end

local validation = {}

---@param v number | string
---@param err string
---@return number
---@return ui.SizeMode
local function size(v, err)
	if type(v) == "string" then
		if v == "auto" then
			return 0, SizeMode.Auto
		elseif v == "fit" then
			return 0, SizeMode.Fit
		else
			return 0, errmsg(SizeMode.Auto, err)
		end
	end

	return asrt_type(v, 0, "number", err), SizeMode.Fixed
end

---@param v number
---@param err string
local function number_min_zero(v, err)
	v = asrt_type(v, 0, "number", err)
	return math.max(0, v)
end

---@param v number | string
---@return number
---@return ui.SizeMode
function validation.width(v)
	return size(v, "Expected width to be a number, 'auto' or 'fit")
end

---@param v number | string
---@return number
---@return ui.SizeMode | number
function validation.height(v)
	return size(v, "Expected height to be a number, 'auto' or 'fit")
end

---@param v number
---@return number
function validation.min_width(v)
	return number_min_zero(v, "Expected min_width to be a number")
end

---@param v number
---@return number
function validation.min_height(v)
	return number_min_zero(v, "Expected min_height to be a number")
end

---@param v number
---@return number
function validation.max_width(v)
	return number_min_zero(v, "Expected max_width to be a number")
end

---@param v number
---@return number
function validation.max_height(v)
	return number_min_zero(v, "Expected max_height to be a number")
end

---@param v number | table<number>
---@return number
---@return number
---@return number
---@return number
function validation.padding(v)
	if type(v) == "table" then
		if not is_array_of_type(v, "number", 4, "Expected padding to be a table<number> or a number") then
			return 0, 0, 0, 0
		end
		return v[1], v[2], v[3], v[4]
	end

	assert(type(v) == "number", "Expected padding to be a table<number> or a number")
	return v, v, v, v
end

---@param v string
---@return ui.Arrange
function validation.arrange(v)
	if v == "absolute" then
		return Arrange.Absolute
	elseif v == "flow_h" then
		return Arrange.FlowH
	elseif v == "flow_v" then
		return Arrange.FlowV
	end

	return errmsg(Arrange.Absolute, "Expected 'absolute', 'flow_h' or 'flow_v' for arrange")
end

---@param v string
---@return ui.JustifyContent
function validation.justify_content(v)
	if v == "start" then
		return JustifyContent.Start
	elseif v == "center" then
		return JustifyContent.Center
	elseif v == "end" then
		return JustifyContent.End
	elseif v == "space_between" then
		return JustifyContent.SpaceBetween
	end

	return errmsg(
		JustifyContent.Start,
		"Expected 'start', 'center', 'end' or 'space_between' for justify_content"
	)
end

---@param v string
---@param err string
---@return ui.AlignItems
local function align(v, err)
	if v == "start" then
		return AlignItems.Start
	elseif v == "center" then
		return AlignItems.Center
	elseif v == "end" then
		return AlignItems.End
	elseif v == "stretch" then
		return AlignItems.Stretch
	end
	return errmsg(AlignItems.Start, err)
end

---@param v string
---@return ui.AlignItems
function validation.align_items(v)
	return align(v, "Expected 'start', 'center', 'end' or 'stretch' for align_items")
end

---@param v string
---@return ui.AlignItems
function validation.align_self(v)
	return align(v, "Expected 'start', 'center', 'end' or 'stretch' for align_items")
end

---@param v number
---@return number
function validation.flex_grow(v)
	return number_min_zero(v, "Expected flex_grow to be a number")
end

---@param v number
---@return number
function validation.child_gap(v)
	return number_min_zero(v, "Expected child_gap to be a number")
end

---@param v string
---@return ui.Pivot
local function pivot(v, err)
	v = asrt_type(v, "top_left", "string", err)
	local p = pivots[v]
	if not p then
		p = errmsg(Pivot.TopLeft, err)
	end
	return p
end

---@param v string
---@return ui.Pivot
function validation.origin(v)
	return pivot(v, "Invalid origin pivot name")
end

---@param v string
---@return ui.Pivot
function validation.anchor(v)
	return pivot(v, "Invalid anchor pivot name")
end

---@param v string
---@return ui.Pivot
function validation.pivot(v)
	return pivot(v, "Invalid pivot name")
end

local default_shadow = { x = 0, y = 0, radius = 0 }

---@param t { x: number, y: number, radius: number, color: ui.Color }
---@return { x: number, y: number, radius: number, color: ui.Color }
function validation.shadow(t)
	t = asrt_type(t, default_shadow, "table", "Expected shadow to be a table")
	t.x = asrt_type(t.x or 0, 0, "number", "Expected shadow.x to be a number")
	t.y = asrt_type(t.y or 0, 0, "number", "Expected shadow.y to be a number")
	t.radius = asrt_type(t.radius, 0, "number", "Expected shadow.radius to be a number")
	if not is_array_of_type(t.color, "number", 4, "Expected shadow.color to be an array of 4 numbers") then
		t.color = default_color
	end
	return t
end

local default_blur = { type = "gaussian", radius = 2 }

---@param t { type: "gaussian" | "kawase", radius: number}
---@return { type: "gaussian" | "kawase", radius: number}
function validation.bd_blur(t)
	t = asrt_type(t, default_blur, "table", "Expected bd_blur to be a table")
	t.type = asrt_type(t.type, "gaussian", "string", "Expexted bd_blur.type to be a string")
	t.radius = asrt_type(t.radius, 2, "number", "Expexted bd_blur.radius to be a number")
	return t
end

---@param v number
---@return number
function validation.bd_brightness(v)
	return asrt_type(v, 1, "number", "Expected bd_brightness to be a number")
end

---@param v number
---@return number
function validation.bd_contrast(v)
	return asrt_type(v, 1, "number", "Expected bd_contrast to be a number")
end

---@param v number
---@return number
function validation.bd_saturation(v)
	return asrt_type(v, 1, "number", "Expected bd_saturation to be a number")
end

---@param v number
---@return number
function validation.brightness(v)
	return asrt_type(v, 1, "number", "Expected brightness to be a number")
end

---@param v number
---@return number
function validation.contrast(v)
	return asrt_type(v, 1, "number", "Expected contrast to be a number")
end

---@param v number
---@return number
function validation.saturation(v)
	return asrt_type(v, 1, "number", "Expected saturation to be a number")
end

local default_gradient_colors = {
	{ t = 0, color = { 1, 0, 1, 1 } },
	{ t = 1, color = { 0, 1, 1, 1 } }
}

local default_linear_gradient = {
	colors = default_gradient_colors,
	angle = 0
}

---@param t { colors: table<{ t: number, color: ui.Color}>, angle: number? }
---@return { colors: table<{ t: number, color: ui.Color}>, angle: number? }
function validation.linear_gradient(t)
	t = asrt_type(t, default_linear_gradient, "table", "Expected linear_gradient to be a table")
	t.colors = asrt_type(t.colors, default_gradient_colors, "table", "Expected linear_gradient.colors to be a table")

	local colors_len = #t.colors
	for i, v in ipairs(t.colors) do
		local default_t = i / colors_len
		v.t = asrt_type(v.t or default_t, default_t, "number", "Expected linear_gradient.colors[?].t to be a number")

		local color_valid = is_array_of_type(
			v.color,
			"number",
			4,
			"Expected linear_gradient.colors[?].color to be a table of 4 numbers"
		)

		if not color_valid then
			v.color = default_color
		end
	end

	t.angle = asrt_type(t.angle or 0, 0, "number", "Expected linear_gradient.angle to be a number")
	return t
end

---@param v [number, number, number, number] | number
---@param err string
---@return [number, number, number, number]
local function border_radius(v, err)
	if type(v) == "table" then
		local valid = is_array_of_type(v, "number", 4, err)
		if not valid then
			v = { 1, 1, 1, 1 }
		end
		return v
	end

	v = asrt_type(v, 0, "number", err)
	return { v, v, v, v }
end

---@param v [number, number, number, number] | number
---@return [number, number, number, number]
function validation.border_radius(v)
	return border_radius(v, "Expected border_radius to be an array of 4 numbers or a number")
end

---@param v [number, number, number, number] | number
---@return [number, number, number, number]
function validation.bd_border_radius(v)
	return border_radius(v, "Expected border_radius to be an array of 4 numbers or a number")
end

---@param v table<number>
---@return table<number>
function validation.color(v)
	if not is_array_of_type(v, "number", 4, "Expected color to be an array of 4 numbers") then
		return default_color
	end
	return v
end

---@param v number
---@return number
function validation.alpha(v)
	return asrt_type(v, 1, "number", "Expected alpha to be a number")
end

---@param v table<number>
---@return table<number>
function validation.background_color(v)
	if not is_array_of_type(v, "number", 4, "Expected background_color to be an array of 4 numbers") then
		return default_color
	end
	return v
end

---@param v string
---@return string
function validation.blend_mode(v)
	return asrt_type(v, "alpha", "string", "Expected blend_mode to be a string")
end

---@param v string
---@return string
function validation.blend_mode_alpha(v)
	return asrt_type(v, "alphamultiply", "string", "Expected blend_mode_alpha to be a string")
end

local default_border = {
	thickness = 2,
	color = { 1, 0, 1, 1 }
}

---@param t { thickness: number, color: ui.Color }
---@return { thickness: number, color: ui.Color }
function validation.border(t)
	t = asrt_type(t, default_border, "table", "Expected border to be a table")
	t.thickness = asrt_type(t.thickness, 0, "number", "Expected border.thickness to be a number")
	if not is_array_of_type(t.color, "number", 4, "Expected border.color to be a table of 4 numbers") then
		t.color = default_color
	end
	return t
end

---@param v string
---@return string
function validation.id(v)
	return asrt_type(v, nil, "string", "Expected id to be a string")
end

---@param v number
---@return number
function validation.z(v)
	return asrt_type(v, 0, "number", "Expected z to be a number")
end

---@param v boolean
---@return boolean
function validation.clip(v)
	return asrt_type(v, false, "boolean", "Expected clip to be a boolean")
end

local default_transform = { x = 0, y = 0, angle = 0, sx = 0, sy = 0, kx = 0, ky = 0 }

---@param v table
---@return table
function validation.transform(v)
	v = asrt_type(v, default_transform, "table", "Expected transform to be a table")
	v.x = asrt_type(v.x or 0, 0, "number", "Expected transform.x to be a number")
	v.y = asrt_type(v.y or 0, 0, "number", "Expected transform.y to be a number")
	v.angle = asrt_type(v.angle or 0, 0, "number", "Expected transform.angle to be a number")
	v.sx = asrt_type(v.sx or 1, 1, "number", "Expected transform.sx to be a number")
	v.sy = asrt_type(v.sy or 1, 1, "number", "Expected transform.sy to be a number")
	v.kx = asrt_type(v.kx or 0, 0, "number", "Expected transform.kx to be a number")
	v.ky = asrt_type(v.ky or 0, 0, "number", "Expected transform.ky to be a number")
	return v
end

return validation
