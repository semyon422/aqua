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
function test.wrap_row_basic(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(120, 100)
	container.layout_box.arrange = LayoutBox.Arrange.WrapRow

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(50, 50)

	engine:updateLayout(container.children)

	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c1.layout_box.y.pos, 0)

	t:eq(c2.layout_box.x.pos, 50)
	t:eq(c2.layout_box.y.pos, 0)

	t:eq(c3.layout_box.x.pos, 0)
	t:eq(c3.layout_box.y.pos, 50)
end

---@param t testing.T
function test.wrap_row_with_gaps(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(110, 100)
	container.layout_box.arrange = LayoutBox.Arrange.WrapRow
	container.layout_box:setChildGap(10)
	container.layout_box:setLineGap(5)

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(50, 50)

	engine:updateLayout(container.children)

	-- c1: 50, gap 10, c2: 50. Total 110. Fits in 110.
	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c1.layout_box.y.pos, 0)

	t:eq(c2.layout_box.x.pos, 60)
	t:eq(c2.layout_box.y.pos, 0)

	-- c3 wraps
	t:eq(c3.layout_box.x.pos, 0)
	t:eq(c3.layout_box.y.pos, 55) -- 50 (height) + 5 (line_gap)
end

---@param t testing.T
function test.wrap_row_auto_size(t)
	local engine = LayoutEngine()

	-- A wrapper to constrain the auto-size container
	local wrapper = new_node()
	wrapper.layout_box:setDimensions(110, 200)

	local container = wrapper:add(new_node())
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()
	container.layout_box.arrange = LayoutBox.Arrange.WrapRow
	container.layout_box:setChildGap(10)
	container.layout_box:setLineGap(5)

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(50, 50)

	engine:updateLayout(wrapper.children)

	-- The container should wrap its children and size to the max line width
	t:eq(container.layout_box.x.size, 110)
	t:eq(container.layout_box.y.size, 105) -- two lines (50 + 5 + 50)
end

---@param t testing.T
function test.wrap_row_intrinsic_size(t)
	local engine = LayoutEngine()

	local wrapper = new_node()
	wrapper.layout_box:setDimensions(110, 200)
	wrapper.layout_box:setAlignItems(Enums.AlignItems.Start)

	local container = wrapper:add(new_node())
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()
	container.layout_box.arrange = LayoutBox.Arrange.WrapRow

	local c1 = container:add(new_node_with_intrinsic_size(60, 40))
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()

	local c2 = container:add(new_node_with_intrinsic_size(60, 40))
	c2.layout_box:setWidthAuto()
	c2.layout_box:setHeightAuto()

	engine:updateLayout(wrapper.children)

	-- c1 and c2 should each be 60 wide, which is > 110 together, so they wrap.
	t:eq(container.layout_box.x.size, 60)
	t:eq(container.layout_box.y.size, 80)
end

---@param t testing.T
function test.wrap_col_basic(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(100, 120)
	container.layout_box.arrange = LayoutBox.Arrange.WrapCol

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(50, 50)

	engine:updateLayout(container.children)

	t:eq(c1.layout_box.x.pos, 0)
	t:eq(c1.layout_box.y.pos, 0)

	t:eq(c2.layout_box.x.pos, 0)
	t:eq(c2.layout_box.y.pos, 50)

	t:eq(c3.layout_box.x.pos, 50)
	t:eq(c3.layout_box.y.pos, 0)
end

---@param t testing.T
function test.wrap_row_max_size(t)
	local engine = LayoutEngine()

	local container = new_node()
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()
	container.layout_box.x.max_size = 100
	container.layout_box.arrange = LayoutBox.Arrange.WrapRow

	local c1 = container:add(new_node_with_intrinsic_size(60, 40))
	c1.layout_box:setWidthAuto()
	c1.layout_box:setHeightAuto()

	local c2 = container:add(new_node_with_intrinsic_size(60, 40))
	c2.layout_box:setWidthAuto()
	c2.layout_box:setHeightAuto()

	engine:updateLayout({container})

	t:eq(container.layout_box.x.size, 60, "container width should be 60")
	t:eq(container.layout_box.y.size, 80, "container height should be 80")
end

---@param t testing.T
function test.wrap_col_align_items_center(t)
	local engine = LayoutEngine()

	-- Root: fixed size 800x600
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.WrapCol

	-- Container: 100px wide, wrap_col, align_items center
	local container = root:add(new_node())
	container.layout_box:setWidth(100)
	container.layout_box:setHeight(400)
	container.layout_box.arrange = LayoutBox.Arrange.WrapCol
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Center)

	-- Child: 40px wide, 40px high
	local child = container:add(new_node())
	child.layout_box:setDimensions(40, 40)

	engine:updateLayout({root})

	-- Expected: child should be centered horizontally in the 100px container.
	-- x_pos = (100 - 40) / 2 = 30
	t:eq(child.layout_box.x.size, 40)
	t:eq(child.layout_box.x.pos, 30, "Child should be centered horizontally in WrapCol")
end

---@param t testing.T
function test.wrap_row_align_items_center(t)
	local engine = LayoutEngine()

	-- Root
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.WrapCol

	-- Container: 100px high, wrap_row, align_items center
	local container = root:add(new_node())
	container.layout_box:setWidth(400)
	container.layout_box:setHeight(100)
	container.layout_box.arrange = LayoutBox.Arrange.WrapRow
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Center)

	-- Child: 40px wide, 40px high
	local child = container:add(new_node())
	child.layout_box:setDimensions(40, 40)

	engine:updateLayout({root})

	-- Expected: child should be centered vertically in the 100px container.
	-- y_pos = (100 - 40) / 2 = 30
	t:eq(child.layout_box.y.size, 40)
	t:eq(child.layout_box.y.pos, 30, "Child should be centered vertically in WrapRow")
end

---Auto-sized WrapCol container should measure cross-axis correctly
---before main-axis size is known during initial layout
---@param t testing.T
function test.wrap_col_initial_measurement(t)
	local engine = LayoutEngine()

	-- Root: fixed size 800x600
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.WrapCol

	-- Parent: 64px wide, 100% height (600px)
	local parent = root:add(new_node())
	parent.layout_box:setWidth(64)
	parent.layout_box:setHeightPercent(1.0)
	parent.layout_box.arrange = LayoutBox.Arrange.WrapCol

	-- Container: WrapCol, Auto size
	local container = parent:add(new_node())
	container.layout_box.arrange = LayoutBox.Arrange.WrapCol
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()

	-- Children: 45x45. 3 children total height 135 < 600.
	-- They should all fit in one column.
	for i = 1, 3 do
		local child = container:add(new_node())
		child.layout_box:setDimensions(45, 45)
	end

	engine:updateLayout({root})

	-- Container width should be 45 (max child width), not 64 (parent width)
	t:eq(container.layout_box.x.size, 45, "Container should have width 45, not 64")
end

return test
