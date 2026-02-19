local table_util = require("table_util")
local math_util = require("math_util")
local LayoutStrategy = require("ui.layout.strategy.LayoutStrategy")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis
local SizeMode = Enums.SizeMode
local math_clamp = math_util.clamp

---@class ui.GridTrack
---@field size number? Fixed size in pixels
---@field percent number? Percentage (0-1)
---@field resolved_size number Calculated size during layout

---@class ui.GridStrategy: ui.LayoutStrategy
---@operator call: ui.GridStrategy
local GridStrategy = LayoutStrategy + {}

-- Reusable tables for GC optimization
local _resolved_cols = {} ---@type number[]
local _resolved_rows = {} ---@type number[]

---Resolve track sizes (columns or rows)
---@param tracks ui.GridTrack[]
---@param available_size number
---@param reuse_table number[] Table to reuse for GC optimization
---@return number[] resolved_sizes
function GridStrategy:resolveTracks(tracks, available_size, reuse_table)
	table_util.clear(reuse_table)

	local resolved = reuse_table

	local total_fixed = 0
	local total_percent = 0

	-- First pass: calculate fixed sizes and sum percentages
	for _, track in ipairs(tracks) do
		if track.size then
			total_fixed = total_fixed + track.size
		elseif track.percent then
			total_percent = total_percent + track.percent
		end
	end

	-- Second pass: resolve percentages
	local remaining = available_size - total_fixed
	for i, track in ipairs(tracks) do
		if track.size then
			resolved[i] = track.size
		elseif track.percent then
			resolved[i] = remaining * track.percent
		else
			resolved[i] = 0 -- Auto track (not implemented)
		end
	end

	return resolved
end

---Get cell position and size for a child
---Grid positions are 1-indexed (like CSS Grid)
---@param node ui.Node
---@param child ui.Node
---@return number x_pos, number y_pos, number width, number height
function GridStrategy:getCellBounds(node, child)
	local layout_box = node.layout_box
	local columns = layout_box.grid_columns or {}
	local rows = layout_box.grid_rows or {}

	-- 1-indexed: default to first column/row
	local col = child.layout_box.grid_column or 1
	local row = child.layout_box.grid_row or 1
	local col_span = child.layout_box.grid_col_span or 1
	local row_span = child.layout_box.grid_row_span or 1

	-- Resolve tracks
	local resolved_cols = self:resolveTracks(columns, layout_box.x:getLayoutSize(), _resolved_cols)
	local resolved_rows = self:resolveTracks(rows, layout_box.y:getLayoutSize(), _resolved_rows)

	-- Calculate position (sum sizes of all tracks before this one)
	local x_pos = layout_box.x.padding_start
	local y_pos = layout_box.y.padding_start

	for i = 1, col - 1 do
		x_pos = x_pos + (resolved_cols[i] or 0)
	end

	for i = 1, row - 1 do
		y_pos = y_pos + (resolved_rows[i] or 0)
	end

	-- Calculate spanned size (sum sizes from col to col + span - 1)
	local width = 0
	local height = 0

	for i = col, col + col_span - 1 do
		width = width + (resolved_cols[i] or 0)
	end

	for i = row, row + row_span - 1 do
		height = height + (resolved_rows[i] or 0)
	end

	return x_pos, y_pos, width, height
end

---Measure all children and set node size
---@param node ui.Node
---@param axis_idx ui.Axis
function GridStrategy:measure(node, axis_idx)
	local layout_box = node.layout_box
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
			self:measure(child, axis_idx)
		end
		return
	end

	-- Auto/Fit: calculate size from grid tracks
	local tracks = (axis_idx == Axis.X) and layout_box.grid_columns or layout_box.grid_rows

	if not tracks or #tracks == 0 then
		-- No tracks defined, fallback to content
		axis.size = 0
		return
	end

	-- Sum track sizes
	local s = 0
	for _, track in ipairs(tracks) do
		if track.size then
			s = s + track.size
		elseif track.percent and axis.mode == SizeMode.Fixed then
			-- Can't resolve percent without parent size
			s = s + axis.size * track.percent
		end
	end

	s = axis.padding_start + s + axis.padding_end
	axis.size = math_clamp(s, min_s, max_s)

	-- Measure children with cell constraints
	for _, child in ipairs(node.children) do
		local x_pos, y_pos, width, height = self:getCellBounds(node, child)

		-- Constrain child to cell size
		local child_x = child.layout_box.x
		local child_y = child.layout_box.y

		-- If child is Auto, use cell size
		if child_x.mode == SizeMode.Auto then
			child_x.size = math_clamp(width, child_x.min_size, child_x.max_size)
		else
			self:measureAxis(child, Axis.X)
		end

		if child_y.mode == SizeMode.Auto then
			child_y.size = math_clamp(height, child_y.min_size, child_y.max_size)
		else
			self:measureAxis(child, Axis.Y)
		end
	end
end

---Measure a single axis (helper for recursive measurement)
---@param child ui.Node
---@param axis_idx ui.Axis
function GridStrategy:measureAxis(child, axis_idx)
	local axis = self:getAxis(child, axis_idx)

	if axis.mode == SizeMode.Fixed or axis.mode == SizeMode.Percent then
		local s = axis.preferred_size
		if axis.mode == SizeMode.Percent and child.parent then
			local parent_axis = self:getAxis(child.parent, axis_idx)
			s = s * parent_axis:getLayoutSize()
		end
		axis.size = math_clamp(s, axis.min_size, axis.max_size)
	end

	-- Recurse into grandchildren
	for _, grandchild in ipairs(child.children) do
		self:measureAxis(grandchild, axis_idx)
	end
end

---Distribute extra space (not applicable for grid, but recurse into children)
---@param node ui.Node
---@param axis_idx ui.Axis
function GridStrategy:grow(node, axis_idx)
	-- Grid doesn't use grow, but children might
	for _, child in ipairs(node.children) do
		-- Recurse - children might have their own layout modes
		self:grow(child, axis_idx)
	end
end

---Position all children
---@param node ui.Node
function GridStrategy:arrange(node)
	for _, child in ipairs(node.children) do
		local x_pos, y_pos, width, height = self:getCellBounds(node, child)

		-- Position child in its cell
		child.layout_box.x.pos = x_pos + child.layout_box.x.margin_start
		child.layout_box.y.pos = y_pos + child.layout_box.y.margin_start

		-- Recurse into children
		self:arrange(child)
	end
end

return GridStrategy
