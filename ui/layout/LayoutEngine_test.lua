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
	local n1 = container:add(new_node_with_intrinsic_size(64, 48))
	local n2 = container:add(new_node_with_intrinsic_size(64, 48))
	n1.layout_box:setWidthAuto()
	n1.layout_box:setHeightAuto()
	n2.layout_box:setWidthAuto()
	n2.layout_box:setHeightAuto()

	engine:updateLayout(container.children)

	-- Should use intrinsic size
	t:eq(n1.layout_box.x.size, 64)
	t:eq(n1.layout_box.y.size, 48)
	t:eq(n2.layout_box.x.size, 64)
	t:eq(n2.layout_box.y.size, 48)
	t:eq(container.layout_box.x.size, 64)
	t:eq(container.layout_box.y.size, 96)
end

---@param t testing.T
function test.intrinsic_size_with_fixed_width(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(100, 100)
	container.layout_box.arrange = LayoutBox.Arrange.FlexRow
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch

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
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch

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
function test.percent_child_with_changing_intrinsic_size(t)
	-- Test that parent with Auto height correctly shrinks when intrinsic child shrinks
	-- This tests the fix for the bug where Percent children used stale parent size
	-- Root (FlexRow, 100% width)
	--   └── container (Stack, Auto height)
	--         ├── percent_child (100% height - should follow container)
	--         └── intrinsic_child (Auto - determines container size)
	local engine = LayoutEngine()

	-- Root with fixed dimensions
	local root = new_node()
	root.layout_box:setDimensions(200, 200)
	root.layout_box.arrange = LayoutBox.Arrange.FlexRow
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch container

	-- Container with Auto height (Stack is now default)
	local container = root:add(new_node())
	container.layout_box:setWidth(100)
	container.layout_box:setHeightAuto()
	-- container.layout_box.arrange = LayoutBox.Arrange.Stack -- Stack is default now

	-- Percent height child
	local percent_child = container:add(new_node())
	percent_child.layout_box:setWidth(50)
	percent_child.layout_box:setHeightPercent(1.0) -- 100% of parent

	-- Intrinsic size child that determines container height
	local intrinsic_child = container:add(new_node_with_intrinsic_size(50, 100))
	intrinsic_child.layout_box:setWidth(50)
	intrinsic_child.layout_box:setHeightAuto()

	-- First layout: intrinsic child has height 100
	engine:updateLayout(container.children)
	t:eq(container.layout_box.y.size, 100, "container height should be 100 from intrinsic child")
	t:eq(percent_child.layout_box.y.size, 100, "percent child should be 100% of 100")

	-- Simulate intrinsic child shrinking (like text unwrapping)
	intrinsic_child.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 50
		else
			return 32 -- Height shrunk from 100 to 32
		end
	end
	intrinsic_child.layout_box:markDirty(Axis.Both)

	-- Second layout: intrinsic child now has height 32
	engine:updateLayout(container.children)
	t:eq(container.layout_box.y.size, 32, "container height should shrink to 32")
	t:eq(percent_child.layout_box.y.size, 32, "percent child should be 100% of 32")
end

---@param t testing.T
function test.stack_container_auto_size_from_children(t)
	-- Test that a Stack container with Auto size correctly calculates
	-- its size based on children's sizes (max of children)
	local engine = LayoutEngine()
	local container = new_node()
	-- container.layout_box.arrange = LayoutBox.Arrange.Stack -- Stack is default
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()

	-- Child with size (100, 80)
	local child1 = container:add(new_node())
	child1.layout_box:setDimensions(100, 80)

	-- Child with size (50, 50)
	local child2 = container:add(new_node())
	child2.layout_box:setDimensions(50, 50)

	engine:updateLayout({container})

	-- Container should size to max of children
	-- Width: max(100, 50) = 100
	-- Height: max(80, 50) = 80
	t:eq(container.layout_box.x.size, 100)
	t:eq(container.layout_box.y.size, 80)

	-- Children should overlap at position 0 (default Start alignment)
	t:eq(child1.layout_box.x.pos, 0)
	t:eq(child1.layout_box.y.pos, 0)
	t:eq(child2.layout_box.x.pos, 0)
	t:eq(child2.layout_box.y.pos, 0)
end

---@param t testing.T
function test.stack_container_with_margins(t)
	-- Test that margins are correctly accounted for in Stack layout
	local engine = LayoutEngine()
	local container = new_node()
	-- container.layout_box.arrange = LayoutBox.Arrange.Stack -- Stack is default
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()

	-- Child with size (100, 50) and margins
	local child = container:add(new_node())
	child.layout_box:setDimensions(100, 50)
	child.layout_box.x.margin_start = 5
	child.layout_box.x.margin_end = 10
	child.layout_box.y.margin_start = 3
	child.layout_box.y.margin_end = 7

	engine:updateLayout({container})

	-- Container size should include the child's size + margins
	-- Width: 100 + 5 + 10 = 115
	-- Height: 50 + 3 + 7 = 60
	t:eq(container.layout_box.x.size, 115)
	t:eq(container.layout_box.y.size, 60)

	-- Child position should include margin_start (Start alignment is default)
	t:eq(child.layout_box.x.pos, 5)
	t:eq(child.layout_box.y.pos, 3)
end

---@param t testing.T
function test.intrinsic_size_in_nested_auto_container(t)
	-- This test reproduces the bug where a Label inside nested containers
	-- gets width=0 because parent size is 0 during measurement
	local engine = LayoutEngine()

	-- Root with fixed size (like Screen)
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.FlexCol

	-- Row container (flex_row, auto size)
	local row = root:add(new_node())
	row.layout_box.arrange = LayoutBox.Arrange.FlexRow
	row.layout_box:setWidthAuto()
	row.layout_box:setHeightAuto()
	row.layout_box:setChildGap(10)

	-- Panel with padding (Stack by default, auto size)
	-- Set align_items = Start to prevent stretching children
	local panel = row:add(new_node())
	panel.layout_box:setWidthAuto()
	panel.layout_box:setHeightAuto()
	panel.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	panel.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)
	panel.layout_box:setPaddings({5, 20, 5, 20}) -- top, right, bottom, left

	-- Label with intrinsic size
	local label = panel:add(new_node_with_intrinsic_size(100, 20))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	engine:updateLayout(root.children)

	-- Label should have its intrinsic width, not 0
	t:eq(label.layout_box.x.size, 100, "label should have intrinsic width")
	t:eq(label.layout_box.y.size, 20, "label should have intrinsic height")

	-- Panel should size to fit label + padding
	t:eq(panel.layout_box.x.size, 140, "panel width should be label + padding") -- 100 + 20 + 20
	t:eq(panel.layout_box.y.size, 30, "panel height should be label + padding") -- 20 + 5 + 5

	-- Row should stretch to fill root width (flex_col default align_items = Stretch)
	t:eq(row.layout_box.x.size, 800, "row width should stretch to root width")
	t:eq(row.layout_box.y.size, 30, "row height should fit panel")
end

---@param t testing.T
function test.intrinsic_size_after_parent_resize(t)
	-- This test reproduces the bug where a Label stays wrapped after parent is resized
	-- Root (FlexCol, fixed size)
	--   Row (FlexRow, Auto size)
	--     Panel (Stack, Auto size, padding)
	--       Label (intrinsic size)
	local engine = LayoutEngine()

	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.FlexCol
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch children

	local row = root:add(new_node())
	row.layout_box.arrange = LayoutBox.Arrange.FlexRow
	row.layout_box:setWidthAuto()
	row.layout_box:setHeightAuto()

	local panel = row:add(new_node())
	panel.layout_box:setWidthAuto()
	panel.layout_box:setHeightAuto()
	panel.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	panel.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)
	panel.layout_box:setPaddings({5, 20, 5, 20})

	local label = panel:add(new_node_with_intrinsic_size(100, 20))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	-- First layout: normal size
	engine:updateLayout(root.children)
	t:eq(label.layout_box.x.size, 100, "initial label width should be intrinsic")

	-- Simulate resize to small width
	root.layout_box:setWidth(1)
	root.layout_box:markDirty(Axis.X)
	row.layout_box:markDirty(Axis.X)
	panel.layout_box:markDirty(Axis.X)
	label.layout_box:markDirty(Axis.X)

	engine:updateLayout(root.children)
	-- Label should still have intrinsic width since parent has Auto mode
	t:eq(label.layout_box.x.size, 100, "label width should still be intrinsic after shrink")

	-- Simulate resize back to large width
	root.layout_box:setWidth(1374)
	root.layout_box:markDirty(Axis.X)
	row.layout_box:markDirty(Axis.X)
	panel.layout_box:markDirty(Axis.X)
	label.layout_box:markDirty(Axis.X)

	engine:updateLayout(root.children)
	t:eq(label.layout_box.x.size, 100, "label width should be intrinsic after expand")
end

-------------------------------------------------------------------------------
-- StackStrategy Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.stack_center_alignment(t)
	-- Test that a child is perfectly centered in a Stack
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(400, 400)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Center)

	local child = container:add(new_node())
	child.layout_box:setDimensions(100, 50)

	engine:updateLayout(container.children)

	-- Child should be centered:
	-- X: (400 - 100) / 2 = 150
	-- Y: (400 - 50) / 2 = 175
	t:eq(child.layout_box.x.pos, 150, "child should be centered on X")
	t:eq(child.layout_box.y.pos, 175, "child should be centered on Y")
	t:eq(child.layout_box.x.size, 100)
	t:eq(child.layout_box.y.size, 50)
end

---@param t testing.T
function test.stack_children_overlap(t)
	-- Test that all children in a Stack overlap (Z-axis stacking)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local child1 = container:add(new_node())
	child1.layout_box:setDimensions(100, 100)

	local child2 = container:add(new_node())
	child2.layout_box:setDimensions(50, 50)

	local child3 = container:add(new_node())
	child3.layout_box:setDimensions(150, 75)

	engine:updateLayout(container.children)

	-- All children should start at position 0 (Start alignment)
	t:eq(child1.layout_box.x.pos, 0)
	t:eq(child1.layout_box.y.pos, 0)
	t:eq(child2.layout_box.x.pos, 0)
	t:eq(child2.layout_box.y.pos, 0)
	t:eq(child3.layout_box.x.pos, 0)
	t:eq(child3.layout_box.y.pos, 0)

	-- Container size should be max of children
	t:eq(container.layout_box.x.size, 150, "container width should be max child width")
	t:eq(container.layout_box.y.size, 100, "container height should be max child height")
end

---@param t testing.T
function test.stack_stretch_alignment(t)
	-- Test that Stretch alignment works in Stack
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 100)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Stretch)

	local child = container:add(new_node())
	child.layout_box:setWidthAuto()
	child.layout_box:setHeightAuto()

	engine:updateLayout(container.children)

	-- Child should stretch to fill container
	t:eq(child.layout_box.x.size, 200, "child should stretch to container width")
	t:eq(child.layout_box.y.size, 100, "child should stretch to container height")
end

---@param t testing.T
function test.stack_end_alignment(t)
	-- Test End alignment in Stack
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 100)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.End)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.End)

	local child = container:add(new_node())
	child.layout_box:setDimensions(50, 30)

	engine:updateLayout(container.children)

	-- Child should be at end:
	-- X: 200 - 50 = 150
	-- Y: 100 - 30 = 70
	t:eq(child.layout_box.x.pos, 150, "child should be at end on X")
	t:eq(child.layout_box.y.pos, 70, "child should be at end on Y")
end

---@param t testing.T
function test.stack_align_self(t)
	-- Test individual child alignment in Stack
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 100)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	-- Parent defaults to Start
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local c1 = container:add(new_node())
	c1.layout_box:setDimensions(50, 30)
	c1.layout_box:setAlignSelf(LayoutBox.AlignItems.End)
	c1.layout_box:setJustifySelf(LayoutBox.JustifyContent.End)

	local c2 = container:add(new_node())
	c2.layout_box:setDimensions(50, 30)
	c2.layout_box:setAlignSelf(LayoutBox.AlignItems.Center)
	c2.layout_box:setJustifySelf(LayoutBox.JustifyContent.Center)

	local c3 = container:add(new_node())
	c3.layout_box:setDimensions(50, 30)
	-- c3 should use parent defaults (Start, Start)

	engine:updateLayout(container.children)

	-- c1 (End, End)
	t:eq(c1.layout_box.x.pos, 150, "c1 should be at end on X")
	t:eq(c1.layout_box.y.pos, 70, "c1 should be at end on Y")

	-- c2 (Center, Center)
	t:eq(c2.layout_box.x.pos, 75, "c2 should be at center on X")
	t:eq(c2.layout_box.y.pos, 35, "c2 should be at center on Y")

	-- c3 (Default: Start, Start)
	t:eq(c3.layout_box.x.pos, 0, "c3 should be at start on X")
	t:eq(c3.layout_box.y.pos, 0, "c3 should be at start on Y")
end

---@param t testing.T
function test.stack_with_padding(t)
	-- Test Stack with padding
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 100)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Center)
	container.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left

	local child = container:add(new_node())
	child.layout_box:setDimensions(50, 30)

	engine:updateLayout(container.children)

	-- Available space = container - padding
	-- Available width: 200 - 20 - 20 = 160
	-- Available height: 100 - 10 - 10 = 80
	-- Center position:
	-- X: 20 + (160 - 50) / 2 = 20 + 55 = 75
	-- Y: 10 + (80 - 30) / 2 = 10 + 25 = 35
	t:eq(child.layout_box.x.pos, 75, "child should be centered with padding on X")
	t:eq(child.layout_box.y.pos, 35, "child should be centered with padding on Y")
end

---@param t testing.T
function test.stack_with_margins(t)
	-- Test Stack with child margins
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 100)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Center)

	local child = container:add(new_node())
	child.layout_box:setDimensions(50, 30)
	child.layout_box:setMargins({5, 10, 5, 10}) -- top, right, bottom, left

	engine:updateLayout(container.children)

	-- Available space = container - margins
	-- Available width: 200 - 10 - 10 = 180
	-- Available height: 100 - 5 - 5 = 90
	-- Center position:
	-- X: (180 - 50) / 2 + 10 = 65 + 10 = 75
	-- Y: (90 - 30) / 2 + 5 = 30 + 5 = 35
	t:eq(child.layout_box.x.pos, 75, "child should be centered with margins on X")
	t:eq(child.layout_box.y.pos, 35, "child should be centered with margins on Y")
end

---@param t testing.T
function test.label_wrapping_with_center_alignment(t)
	-- This test reproduces the EXACT user scenario:
	-- - Root has fixed dimensions
	-- - Screen container has 100% width and height
	-- - Screen has 100% width and height with justify_content="center" align_items="center"
	-- - Label has intrinsic width larger than screen width
	-- - Label should wrap to fit within screen width

	local function new_wrapping_node(intrinsic_width, line_height)
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
					-- Returns full intrinsic width (like unwrapped text)
					return intrinsic_width
				else
					-- Y axis: calculate height based on constraint (wrapping)
					local width = constraint or intrinsic_width
					local lines = math.ceil(intrinsic_width / width)
					return line_height * lines
				end
			end
		}
	end

	local engine = LayoutEngine()

	-- Root: Fixed dimensions (like window)
	local root = new_node()
	root.layout_box:setDimensions(655, 720)

	-- Screen container: 100% width and height
	local screen_container = root:add(new_node())
	screen_container.layout_box:setWidthPercent(1.0)
	screen_container.layout_box:setHeightPercent(1.0)

	-- Screen: 100% width and height with center alignment
	local screen = screen_container:add(new_node())
	screen.layout_box:setWidthPercent(1.0)
	screen.layout_box:setHeightPercent(1.0)
	screen.layout_box:setJustifyContent(LayoutBox.JustifyContent.Center)
	screen.layout_box:setAlignItems(LayoutBox.AlignItems.Center)

	-- Label: intrinsic width 928 (larger than screen's 655)
	local label = screen:add(new_wrapping_node(928, 21))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	engine:updateLayout(root.children)

	-- Label should be constrained to screen width (655)
	-- NOT return its full intrinsic width (928)
	t:eq(root.layout_box.x.size, 655, "root has fixed width")
	t:eq(screen.layout_box.x.size, 655, "screen has 100% of root width")
	t:eq(label.layout_box.x.size, 655, "label should be constrained to screen width, not use intrinsic 928")
end

---@param t testing.T
function test.stack_percent_size_with_margins(t)
	-- Test that Percent size correctly subtracts margins from available space
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 100)
	container.layout_box.arrange = LayoutBox.Arrange.Stack
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local child = container:add(new_node())
	child.layout_box:setWidthPercent(1.0) -- 100%
	child.layout_box:setHeightPercent(0.5) -- 50%
	child.layout_box:setMargins({0, 64, 0, 0}) -- right margin 64

	engine:updateLayout(container.children)

	-- Width: 100% of (200 - 64) = 136
	-- Height: 50% of (100 - 0) = 50
	-- Position: Start alignment -> pos = 0
	t:eq(child.layout_box.x.size, 136, "100% width with 64 margin should be 200-64=136")
	t:eq(child.layout_box.y.size, 50, "50% height with 0 margin should be 100*0.5=50")
	t:eq(child.layout_box.x.pos, 0, "Start alignment should be at 0")
end

return test

