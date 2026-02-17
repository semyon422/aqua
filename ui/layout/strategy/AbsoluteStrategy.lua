local table_util = require("table_util")
local LayoutStrategy = require("ui.layout.strategy.LayoutStrategy")
local Enums = require("ui.layout.Enums")
local math_util = require("math_util")

local SizeMode = Enums.SizeMode
local math_clamp = math_util.clamp
local math_max = math.max

---@class ui.AbsoluteStrategy: ui.LayoutStrategy
---@operator call: ui.AbsoluteStrategy
local AbsoluteStrategy = LayoutStrategy + {}

-- Reusable tables for GC optimization
local growables = {} ---@type ui.Node[]

---@param node ui.Node
---@param axis_idx ui.Axis
function AbsoluteStrategy:measure(node, axis_idx)
	local axis = self:getAxis(node, axis_idx)
	local min_s = axis.min_size
	local max_s = axis.max_size

	-- Fixed or Percent: use predefined size
	if axis.mode == SizeMode.Fixed or axis.mode == SizeMode.Percent then
		local s = axis.preferred_size
		if axis.mode == SizeMode.Percent and node.parent then
			local parent_axis = self:getAxis(node.parent, axis_idx)
			s = s * parent_axis:getLayoutSize()
		end
		axis.size = math_clamp(s, min_s, max_s)

		for _, child in ipairs(node.children) do
			if not child.is_disabled then
				self:measure(child, axis_idx)
			end
		end
		return
	end

	-- Auto/Fit: calculate size from children
	local s = 0.0
	for _, child in ipairs(node.children) do
		if not child.is_disabled then
			self:measure(child, axis_idx)
			local child_axis = self:getAxis(child, axis_idx)
			-- Include child position + size + margins
			s = math_max(s, child_axis.pos + child_axis.size + child_axis:getTotalMargin())
		end
	end

	s = axis.padding_start + s + axis.padding_end
	axis.size = math_clamp(s, min_s, max_s)
end

---Distribute extra space to growing children
---@param node ui.Node
---@param axis_idx ui.Axis
function AbsoluteStrategy:grow(node, axis_idx)
	if #node.children == 0 then
		return
	end

	local axis = self:getAxis(node, axis_idx)
	local available_space = axis:getLayoutSize()

	table_util.clear(growables)

	for _, child in ipairs(node.children) do
		if child.is_disabled then
			goto continue
		end

		local child_axis = self:getAxis(child, axis_idx)

		-- Handle percent sizing
		if child_axis.mode == SizeMode.Percent then
			local parent_size = axis:getLayoutSize()
			local s = child_axis.preferred_size * parent_size
			child_axis.size = math_clamp(s, child_axis.min_size, child_axis.max_size)
		end

		-- Collect growable children
		if child.layout_box.grow > 0 and child_axis.mode == SizeMode.Auto then
			table.insert(growables, child)
		end

		::continue::
	end

	-- Distribute space to growable children
	for _, child in ipairs(growables) do
		local child_axis = self:getAxis(child, axis_idx)
		local new_size = math_clamp(available_space, child_axis.min_size, child_axis.max_size)
		child_axis.size = new_size
	end

	-- Recurse into children
	for _, child in ipairs(node.children) do
		if not child.is_disabled then
			self:grow(child, axis_idx)
		end
	end
end

---Position all children (absolute positioning - children set their own positions)
---@param node ui.Node
function AbsoluteStrategy:arrange(node)
	for _, child in ipairs(node.children) do
		if not child.is_disabled then
			-- Apply margins to position
			local child_x = child.layout_box.x
			local child_y = child.layout_box.y
			child_x.pos = child_x.pos + child_x.margin_start
			child_y.pos = child_y.pos + child_y.margin_start

			self:arrange(child)
		end
	end
end

return AbsoluteStrategy
