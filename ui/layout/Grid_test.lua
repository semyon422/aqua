local LayoutEngine = require("ui.layout.LayoutEngine")
local LayoutBox = require("ui.layout.LayoutBox")

local test = {}

---@return ui.Node
local function new_node()
	return {
		children = {},
		layout_box = LayoutBox(),
		add = function(self, node)
			table.insert(self.children, node)
			node.parent = self
			return node
		end
	}
end

---@param t testing.T
function test.fixed_tracks(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100, 100})
	grid.layout_box:setGridRows({50, 50})

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(1)
	c1.layout_box:setGridRow(1)
	c1.layout_box:setWidth(100)
	c1.layout_box:setHeight(50)

	local c2 = grid:add(new_node())
	c2.layout_box:setGridColumn(3)
	c2.layout_box:setGridRow(2)
	c2.layout_box:setWidth(100)
	c2.layout_box:setHeight(50)

	engine:updateLayout(grid.children)

	t:eq(grid.layout_box.x.size, 300)
	t:eq(grid.layout_box.y.size, 100)

	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c1.layout_box.y.pos, 0)

	t:eq(c2.layout_box.x.pos, 200)
	t:eq(c2.layout_box.y.pos, 50)
end

---@param t testing.T
function test.percent_tracks(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(300, 100)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({"25%", "25%", "25%", "25%"})
	grid.layout_box:setGridRows({"50%", "50%"})

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(3)
	c1.layout_box:setGridRow(1)
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()

	engine:updateLayout(grid.children)

	t:eq(c1.layout_box.x.pos, 150)
	t:eq(c1.layout_box.y.pos, 0)
end

---@param t testing.T
function test.mixed_tracks(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(400, 100)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, "50%", 100})
	grid.layout_box:setGridRows({30, "40%", 30})

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(2)
	c1.layout_box:setGridRow(2)
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()

	local c2 = grid:add(new_node())
	c2.layout_box:setGridColumn(3)
	c2.layout_box:setGridRow(3)
	c2.layout_box:setWidthAuto()
	c2.layout_box:setHeightAuto()

	engine:updateLayout(grid.children)

	-- Column 2: 50% of (400 - 100 - 100) = 100
	t:eq(c1.layout_box.x.pos, 100)

	-- Row 2: 40% of (100 - 30 - 30) = 16
	t:eq(c1.layout_box.y.pos, 30)

	-- Because the grid has Fixed size dimensions, it won't set the size to children
	-- Auto and Fit would give children the size of the cell
	t:eq(c1.layout_box.x.size, 0)
	t:eq(c2.layout_box.x.size, 0)

	t:eq(c2.layout_box.x.pos, 200) -- 100 + (WIDTH - 100 - 100) * 0.5
	t:eq(c2.layout_box.y.pos, 46) -- 30 + (HEIGHT - 30 - 30) * 0.4
end

---@param t testing.T
function test.column_span(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(300, 50)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100, 100})
	grid.layout_box:setGridRows({50})

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(1)
	c1.layout_box:setGridColSpan(2)
	c1.layout_box:setWidth(200)
	c1.layout_box:setHeight(50)

	local c2 = grid:add(new_node())
	c2.layout_box:setGridColumn(3)
	c2.layout_box:setWidthAuto()
	c2.layout_box:setHeightAuto()

	engine:updateLayout(grid.children)

	-- Should be positioned at column 1
	t:eq(c1.layout_box.x.pos, 0)

	t:eq(c2.layout_box.x.pos, 200)
end

---@param t testing.T
function test.row_span(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(100, 150)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100})
	grid.layout_box:setGridRows({50, 50, 50})

	local c1 = grid:add(new_node())
	c1.layout_box:setGridRow(1)
	c1.layout_box:setGridRowSpan(2)
	c1.layout_box:setWidth(100)
	c1.layout_box:setHeight(100)

	local c2 = grid:add(new_node())
	c2.layout_box:setGridRow(3)
	c2.layout_box:setWidthAuto()
	c2.layout_box:setHeightAuto()

	engine:updateLayout(grid.children)

	-- Should be positioned at row 1
	t:eq(c1.layout_box.y.pos, 0)
	t:eq(c2.layout_box.y.pos, 100)
end

---@param t testing.T
function test.padding(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(300, 100)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100})
	grid.layout_box:setGridRows({50, 50})
	grid.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(1)
	c1.layout_box:setGridRow(1)
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()

	engine:updateLayout(grid.children)

	-- Position should account for left and top padding
	t:eq(c1.layout_box.x.pos, 20)
	t:eq(c1.layout_box.y.pos, 10)
end

---@param t testing.T
function test.margins(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(300, 100)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100})
	grid.layout_box:setGridRows({50, 50})

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(2)
	c1.layout_box:setGridRow(2)
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()
	c1.layout_box:setMargins({5, 10, 5, 10}) -- top, right, bottom, left

	engine:updateLayout(grid.children)

	-- Position should include left and top margins
	t:eq(c1.layout_box.x.pos, 110)
	t:eq(c1.layout_box.y.pos, 55)
end

---@param t testing.T
function test.default_position(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setDimensions(200, 100)
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100})
	grid.layout_box:setGridRows({50, 50})

	local c1 = grid:add(new_node())
	-- No explicit column/row set, should default to (1, 1)
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()

	local c2 = grid:add(new_node())
	-- Same here, should default to (1, 1)
	-- In CSS child would be at (2, 1)
	c2.layout_box:setWidthAuto()
	c2.layout_box:setHeightAuto()

	engine:updateLayout(grid.children)

	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c1.layout_box.y.pos, 0)

	t:eq(c2.layout_box.x.pos, 0)
	t:eq(c2.layout_box.y.pos, 0)
end

---@param t testing.T
function test.auto_container_size(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100, 100})
	grid.layout_box:setGridRows({50, 50})
	grid.layout_box:setWidthAuto()
	grid.layout_box:setHeightAuto()

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(1)
	c1.layout_box:setGridRow(1)

	engine:updateLayout(grid.children)

	-- Grid size should be sum of track sizes
	t:eq(grid.layout_box.x.size, 300)
	t:eq(grid.layout_box.y.size, 100)

	-- Child gets the size of the cell. 
	-- grid is Auto and c1 is Auto
	t:eq(c1.layout_box.x.size, 100)
	t:eq(c1.layout_box.y.size, 50)
end

---@param t testing.T
function test.min_max_constraints(t)
	local engine = LayoutEngine()
	local grid = new_node()
	grid.layout_box:setArrange(LayoutBox.Arrange.Grid)
	grid.layout_box:setGridColumns({100, 100})
	grid.layout_box:setGridRows({50, 50})
	grid.layout_box:setWidthAuto()
	grid.layout_box:setHeightAuto()

	local c1 = grid:add(new_node())
	c1.layout_box:setGridColumn(1)
	c1.layout_box:setGridRow(1)
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()
	c1.layout_box:setWidthLimits(50, 80)
	c1.layout_box:setHeightLimits(20, 40)

	engine:updateLayout(grid.children)

	-- Auto size should be clamped to min/max (cell is 100x50, but max limits apply)
	t:eq(c1.layout_box.x.size, 80)
	t:eq(c1.layout_box.y.size, 40)
end

return test
