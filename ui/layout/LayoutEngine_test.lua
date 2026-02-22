local LayoutEngine = require("ui.layout.LayoutEngine")
local LayoutBox = require("ui.layout.LayoutBox")
local Enums = require("ui.layout.Enums")

local Axis = Enums.Axis

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

---@param width number
---@param height number
---@return ui.Node
local function new_node_with_intrinsic_size(width, height)
	return {
		children = {},
		layout_box = LayoutBox(),
		add = function(self, node)
			table.insert(self.children, node)
			node.parent = self
			return node
		end,
		---@param axis_idx ui.Axis
		---@param constraint number?
		---@return number
		getIntrinsicSize = function(self, axis_idx, constraint)
			if axis_idx == Axis.X then
				return width
			else
				return height
			end
		end
	}
end

---@param t testing.T
function test.flex_row_basic(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(100, 100)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 100)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(100, 100)

	engine:updateLayout(container.children)

	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c2.layout_box.x.pos, 100)
	t:eq(c3.layout_box.x.pos, 150)

	t:eq(c1.layout_box.y.pos, 0)
	t:eq(c2.layout_box.y.pos, 0)
	t:eq(c3.layout_box.y.pos, 0)

	t:eq(c1.layout_box.x.size, 100)
	t:eq(c1.layout_box.y.size, 100)

	t:eq(c2.layout_box.x.size, 50)
	t:eq(c2.layout_box.y.size, 100)

	t:eq(c3.layout_box.x.size, 100)
	t:eq(c3.layout_box.y.size, 100)
end

---@param t testing.T
function test.flex_col_basic(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlexCol

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(100, 100)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(100, 100)

	engine:updateLayout(container.children)

	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c2.layout_box.x.pos, 0)
	t:eq(c3.layout_box.x.pos, 0)

	t:eq(c1.layout_box.y.pos, 0)
	t:eq(c2.layout_box.y.pos, 100)
	t:eq(c3.layout_box.y.pos, 150)
end

---@param t testing.T
function test.justify_content(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(100, 100)
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(10, 10)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(10, 10)

	container.layout_box.justify_content = LayoutBox.JustifyContent.Start
	engine:updateLayout(container.children)
	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c2.layout_box.x.pos, 10)

	container.layout_box.justify_content = LayoutBox.JustifyContent.Center
	engine:updateLayout(container.children)
	t:eq(c1.layout_box.x.pos, 40)
	t:eq(c2.layout_box.x.pos, 50)

	container.layout_box.justify_content = LayoutBox.JustifyContent.End
	engine:updateLayout(container.children)
	t:eq(c1.layout_box.x.pos, 80)
	t:eq(c2.layout_box.x.pos, 90)

	container.layout_box.justify_content = LayoutBox.JustifyContent.SpaceBetween
	engine:updateLayout(container.children)
	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c2.layout_box.x.pos, 90)
end

---@param t testing.T
function test.align_items(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(100, 100)
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(10, 10)
	c1.layout_box.align_self = LayoutBox.AlignItems.Start

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(10, 10)
	c2.layout_box.align_self = LayoutBox.AlignItems.Center

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(10, 10)
	c3.layout_box.align_self = LayoutBox.AlignItems.End

	local c4 = container:add(new_node())
	c4.layout_box:setDimensions(10, 10)
	c4.layout_box.align_self = LayoutBox.AlignItems.Stretch

	engine:updateLayout(container.children)

	t:eq(c1.layout_box.y.pos, 0)
	t:eq(c2.layout_box.y.pos, 45)
	t:eq(c3.layout_box.y.pos, 90)
	t:eq(c4.layout_box.y.pos, 0)
end

---@param t testing.T
function test.percent_size(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 200)
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = container:add(new_node())
	c1.layout_box:setWidthPercent(0.5)
	c1.layout_box:setHeightPercent(0.25)

	local c2 = container:add(new_node())
	c2.layout_box:setWidthPercent(0.3)
	c2.layout_box:setHeight(50)

	engine:updateLayout({c1, c2})

	t:eq(c1.layout_box.x.size, 100)
	t:eq(c1.layout_box.y.size, 50)

	t:eq(c2.layout_box.x.size, 60)
	t:eq(c2.layout_box.y.size, 50)
end

---@param t testing.T
function test.flex_row_reversed(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	container.layout_box:setReversed(true)

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(100, 100)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 100)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(100, 100)

	engine:updateLayout(container.children)

	-- Visual order should be c3, c2, c1
	t:eq(c3.layout_box.x.pos, 0)
	t:eq(c2.layout_box.x.pos, 100)
	t:eq(c1.layout_box.x.pos, 150)
end

---@param t testing.T
function test.flex_col_reversed(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setArrange(LayoutBox.Arrange.FlexCol)
	container.layout_box:setReversed(true)

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(100, 100)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(100, 50)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(100, 100)

	engine:updateLayout(container.children)

	-- Visual order should be c3, c2, c1
	t:eq(c3.layout_box.y.pos, 0)
	t:eq(c2.layout_box.y.pos, 100)
	t:eq(c1.layout_box.y.pos, 150)
end

---@param t testing.T
function test.margins(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 200)
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(50, 50)
	c1.layout_box:setMargins({10, 20, 10, 20}) -- top, right, bottom, left

	engine:updateLayout({c1})

	-- Position should include left margin
	t:eq(c1.layout_box.x.pos, 20)
	t:eq(c1.layout_box.y.pos, 10)
end

---@param t testing.T
function test.intrinsic_size_flex_row(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	-- Node with intrinsic size (e.g., texture 64x48)
	local intrinsic_node = container:add(new_node_with_intrinsic_size(64, 48))
	intrinsic_node.layout_box:setWidthAuto()
	intrinsic_node.layout_box:setHeightAuto()

	engine:updateLayout(container.children)

	-- Should use intrinsic size
	t:eq(intrinsic_node.layout_box.x.size, 64)
	t:eq(intrinsic_node.layout_box.y.size, 48)
end

---@param t testing.T
function test.intrinsic_size_flex_col(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlexCol

	-- Node with intrinsic size (e.g., texture 64x48)
	local intrinsic_node = container:add(new_node_with_intrinsic_size(64, 48))
	intrinsic_node.layout_box:setWidthAuto()
	intrinsic_node.layout_box:setHeightAuto()

	engine:updateLayout(container.children)

	-- Should use intrinsic size
	t:eq(intrinsic_node.layout_box.x.size, 64)
	t:eq(intrinsic_node.layout_box.y.size, 48)
end

---@param t testing.T
function test.intrinsic_size_with_fixed_width(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(100, 100)
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	-- Node with intrinsic size but fixed width
	local intrinsic_node = container:add(new_node_with_intrinsic_size(64, 48))
	intrinsic_node.layout_box:setWidth(50) -- Fixed width
	intrinsic_node.layout_box:setHeightAuto() -- Auto height from intrinsic

	engine:updateLayout(container.children)

	-- Width should be fixed, height from intrinsic
	t:eq(intrinsic_node.layout_box.x.size, 50)
	t:eq(intrinsic_node.layout_box.y.size, 48)
end

---@param t testing.T
function test.intrinsic_size_absolute(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.Absolute

	-- Node with intrinsic size in absolute layout
	local intrinsic_node = container:add(new_node_with_intrinsic_size(100, 200))
	intrinsic_node.layout_box:setWidthAuto()
	intrinsic_node.layout_box:setHeightAuto()

	engine:updateLayout(container.children)

	-- Should use intrinsic size
	t:eq(intrinsic_node.layout_box.x.size, 100)
	t:eq(intrinsic_node.layout_box.y.size, 200)
end

---@param t testing.T
function test.intrinsic_size_container_sizing(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()

	-- Add node with intrinsic size
	container:add(new_node_with_intrinsic_size(80, 60))

	engine:updateLayout({container})

	-- Container should size to fit the intrinsic size of child
	t:eq(container.layout_box.x.size, 80)
	t:eq(container.layout_box.y.size, 60)
end

---@param t testing.T
function test.intrinsic_size_mixed_with_fixed(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow

	-- Node with intrinsic size
	local intrinsic_node = container:add(new_node_with_intrinsic_size(64, 48))
	intrinsic_node.layout_box:setWidthAuto()
	intrinsic_node.layout_box:setHeightAuto()

	-- Node with fixed size
	local fixed_node = container:add(new_node())
	fixed_node.layout_box:setDimensions(50, 100)

	engine:updateLayout(container.children)

	-- Both should have correct sizes
	t:eq(intrinsic_node.layout_box.x.size, 64)
	t:eq(intrinsic_node.layout_box.y.size, 48)
	t:eq(fixed_node.layout_box.x.size, 50)
	t:eq(fixed_node.layout_box.y.size, 100)

	-- Positions should be sequential
	t:eq(intrinsic_node.layout_box.x.pos, 0)
	t:eq(fixed_node.layout_box.x.pos, 64)
end

---@param t testing.T
function test.mixed_strategies_tree(t)
	-- Test a tree with multiple layout strategies at different levels
	-- Root (Absolute)
	--   └── flex_container (FlexRow)
	--         ├── item1
	--         └── grid_container (Grid)
	--               ├── grid_item1
	--               └── grid_item2
	local engine = LayoutEngine()

	-- Root with absolute layout
	local root = new_node()
	root.layout_box:setDimensions(400, 300)
	root.layout_box.arrange = LayoutBox.Arrange.Absolute

	-- Flex container positioned at (10, 20)
	local flex_container = root:add(new_node())
	flex_container.layout_box:setDimensions(200, 200)
	flex_container.layout_box.arrange = LayoutBox.Arrange.FlexRow
	flex_container.layout_box.x.pos = 10
	flex_container.layout_box.y.pos = 20

	-- Item in flex container
	local item1 = flex_container:add(new_node())
	item1.layout_box:setDimensions(50, 100)

	-- Grid container as second item in flex
	local grid_container = flex_container:add(new_node())
	grid_container.layout_box:setDimensions(100, 100)
	grid_container.layout_box.arrange = LayoutBox.Arrange.Grid
	grid_container.layout_box:setGridColumns({50, 50})
	grid_container.layout_box:setGridRows({50, 50})

	-- Grid items
	local grid_item1 = grid_container:add(new_node())
	grid_item1.layout_box:setDimensions(50, 50)
	grid_item1.layout_box:setGridColumn(1)
	grid_item1.layout_box:setGridRow(1)

	local grid_item2 = grid_container:add(new_node())
	grid_item2.layout_box:setDimensions(50, 50)
	grid_item2.layout_box:setGridColumn(2)
	grid_item2.layout_box:setGridRow(1)

	engine:updateLayout(root.children)

	-- Flex container should be at (10, 20) (absolute position preserved)
	t:eq(flex_container.layout_box.x.pos, 10)
	t:eq(flex_container.layout_box.y.pos, 20)

	-- item1 should be at (0, 0) relative to flex container
	t:eq(item1.layout_box.x.pos, 0)
	t:eq(item1.layout_box.y.pos, 0)

	-- grid_container should be at (50, 0) relative to flex container (after item1)
	t:eq(grid_container.layout_box.x.pos, 50)
	t:eq(grid_container.layout_box.y.pos, 0)

	-- grid_item1 should be at (0, 0) relative to grid container
	t:eq(grid_item1.layout_box.x.pos, 0)
	t:eq(grid_item1.layout_box.y.pos, 0)

	-- grid_item2 should be at (50, 0) relative to grid container (second column)
	t:eq(grid_item2.layout_box.x.pos, 50)
	t:eq(grid_item2.layout_box.y.pos, 0)
end

return test
