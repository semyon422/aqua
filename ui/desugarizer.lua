local Node = require("ui.Node")
local Style = require("ui.Style")

---@class ui.Sugar
---@field size [number | "fit" | "grow", number | "fit" | "grow"]?
---@field padding [number, number, number, number]?
---@field arrange? "absolute" | "flow_h" | "flow_v"
---@field pivot "top_left" | "top_center" | "top_right" | "center_left" | "center" | "center_right" | "bottom_left" | "bottom_center" | "bottom_right"
---@field style {[string]: string}

local size_modes = {
	fixed = Node.SizeMode.Fixed,
	fit = Node.SizeMode.Fit,
	grow = Node.SizeMode.Grow
}

local arranges = {
	absolute = Node.Arrange.Absolute,
	flow_h = Node.Arrange.FlowH,
	flow_v = Node.Arrange.FlowV,
}

local pivots = {
	top_left = Node.Pivot.TopLeft,
	top_center = Node.Pivot.TopCenter,
	top_right = Node.Pivot.TopRight,
	center_left = Node.Pivot.CenterLeft,
	center = Node.Pivot.Center,
	center_right = Node.Pivot.CenterRight,
	bottom_left = Node.Pivot.BottomLeft,
	bottom_center = Node.Pivot.BottomCenter,
	bottom_right = Node.Pivot.BottomRight,
}

---@param node ui.Node
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

	if params.style then
		node.style = Style(params.style)
		params.style = nil
	end

	for k, v in pairs(params) do
		node[k] = v
	end
end

return f
