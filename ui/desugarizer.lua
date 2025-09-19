local Drawable = require("ui.Drawable")

---@class ui.Sugar
---@field size [number | "fit" | "grow", number | "fit" | "grow"]?
---@field padding [number, number, number, number]?
---@field arrange? "absolute" | "flow_h" | "flow_v"
---@field pivot "top_left" | "top_center" | "top_right" | "center_left" | "center" | "center_right" | "bottom_left" | "bottom_center" | "bottom_right"

local size_modes = {
	fixed = Drawable.SizeMode.Fixed,
	fit = Drawable.SizeMode.Fit,
	grow = Drawable.SizeMode.Grow
}

local arranges = {
	absolute = Drawable.Arrange.Absolute,
	flow_h = Drawable.Arrange.FlowH,
	flow_v = Drawable.Arrange.FlowV,
}

local pivots = {
	top_left = Drawable.Pivot.TopLeft,
	top_center = Drawable.Pivot.TopCenter,
	top_right = Drawable.Pivot.TopRight,
	center_left = Drawable.Pivot.CenterLeft,
	center = Drawable.Pivot.Center,
	center_right = Drawable.Pivot.CenterRight,
	bottom_left = Drawable.Pivot.BottomLeft,
	bottom_center = Drawable.Pivot.BottomCenter,
	bottom_right = Drawable.Pivot.BottomRight,
}

---@param node ui.Drawable
---@param params ui.Sugar
local function f(node, params)
	if params.size then
		local w, h = assert(params.size[1], "Width isn't defined"), assert(params.size[2], "Height isn't defined")

		if type(w) == "number" then
			node.width = w
		elseif type(w) == "string" then
			node.width_mode = size_modes[w]
		else
			error("Unknown size type (width)")
		end

		if type(h) == "number" then
			node.height = h
		elseif type(h) == "string" then
			node.height_mode = size_modes[h]
		else
			error("Unknown size type (height)")
		end

		params.size = nil
	end

	if params.padding then
		assert(#params.padding == 4, "Padding table doesn't contain 4 values")

		node.padding_left = params.padding[1]
		node.padding_top = params.padding[2]
		node.padding_bottom = params.padding[3]
		node.padding_right = params.padding[4]

		params.padding = nil
	end

	if params.arrange then
		node.arrange = arranges[params.arrange]
		params.arrange = nil
	end

	if params.pivot then
		local p = pivots[params.pivot]
		assert(p, "Unknown pivot")
		node.origin = p
		node.anchor = p
		params.pivot = nil
	end

	for k, v in pairs(params) do
		node[k] = v
	end
end

return f
