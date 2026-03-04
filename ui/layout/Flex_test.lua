local LayoutBox = require("ui.layout.LayoutBox")
local LayoutEngine = require("ui.layout.LayoutEngine")

-- This test only tests sizes
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
function test.fixed_size(t)
	local root = new_node()
	root.layout_box:setWidth(100)
	root.layout_box:setHeight(50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	t:eq(root.layout_box.x.size, 100)
	t:eq(root.layout_box.y.size, 50)
end

---@param t testing.T
function test.fit_size(t)
	local root = new_node()
	root.layout_box.x.mode = LayoutBox.SizeMode.Fit
	root.layout_box.y.mode = LayoutBox.SizeMode.Fit

	local child = root:add(new_node())
	child.layout_box:setWidth(50)
	child.layout_box:setHeight(20)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	t:eq(root.layout_box.x.size, 50)
	t:eq(root.layout_box.y.size, 20)
end

---@param t testing.T
function test.auto_size(t)
	-- Auto should act like Fit
	local root = new_node()
	root.layout_box.x.mode = LayoutBox.SizeMode.Auto
	root.layout_box.y.mode = LayoutBox.SizeMode.Auto

	local child = root:add(new_node())
	child.layout_box:setWidth(50)
	child.layout_box:setHeight(20)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	t:eq(root.layout_box.x.size, 50)
	t:eq(root.layout_box.y.size, 20)
end

---@param t testing.T
function test.grow(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(50)
	c1.layout_box:setGrow(1)

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(50)
	c2.layout_box:setGrow(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Available space: 200 - (50 + 50) = 100
	-- Each gets 50 extra.
	t:eq(c1.layout_box.x.size, 100)
	t:eq(c2.layout_box.x.size, 100)
end

---@param t testing.T
function test.min_max_constraints(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box.arrange = LayoutBox.Arrange.FlexRow

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(50)
	c1.layout_box:setGrow(1)
	c1.layout_box:setWidthLimits(0, 80)

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(50)
	c2.layout_box:setGrow(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Available: 100. Split 50/50.
	-- c1 target: 100. Max: 80. -> 80.
	-- c2 target: 100 + 20 (redistributed) -> 120.
	t:eq(c1.layout_box.x.size, 80)
	t:eq(c2.layout_box.x.size, 120)
end

---@param t testing.T
function test.align_items_stretch(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box.arrange = LayoutBox.Arrange.FlexRow -- Y axis will be stretched.
	root.layout_box.align_items = LayoutBox.AlignItems.Stretch

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(50)
	c1.layout_box:setHeight(20) -- Fixed height

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(50)
	c2.layout_box.y.mode = LayoutBox.SizeMode.Auto

	local c3 = root:add(new_node())
	c3.layout_box.x.mode = LayoutBox.SizeMode.Fit
	c3.layout_box.y.mode = LayoutBox.SizeMode.Fit

	local c3c1 = c3:add(new_node())
	c3c1.layout_box:setDimensions(50, 30)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	t:eq(c1.layout_box.y.size, 20) -- Fixed should not stretch
	t:eq(c2.layout_box.y.size, 100) -- Auto should stretch
	t:eq(c3.layout_box.y.size, 30) -- Fit should not stretch
end

-------------------------------------------------------------------------------
-- Padding Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.flex_row_padding_positions(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = root:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Children should be positioned with padding offset
	t:eq(c1.layout_box.x.pos, 20) -- left padding
	t:eq(c1.layout_box.y.pos, 10) -- top padding
	t:eq(c2.layout_box.x.pos, 70) -- 20 + 50
	t:eq(c2.layout_box.y.pos, 10)
end

---@param t testing.T
function test.flex_row_padding_container_size(t)
	local root = new_node()
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setWidthAuto()
	root.layout_box:setHeightAuto()
	root.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = root:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Container size should include padding
	-- width = left + children + right = 20 + 50 + 50 + 20 = 140
	-- height = top + child + bottom = 10 + 50 + 10 = 70
	t:eq(root.layout_box.x.size, 140)
	t:eq(root.layout_box.y.size, 70)
end

---@param t testing.T
function test.flex_col_padding_positions(t)
	local root = new_node()
	root.layout_box:setWidth(100)
	root.layout_box:setHeight(200)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexCol)
	root.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = root:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Children should be positioned with padding offset in column direction
	t:eq(c1.layout_box.x.pos, 20) -- left padding
	t:eq(c1.layout_box.y.pos, 10) -- top padding
	t:eq(c2.layout_box.x.pos, 20)
	t:eq(c2.layout_box.y.pos, 60) -- 10 + 50
end

-------------------------------------------------------------------------------
-- Margin Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.flex_row_child_margins(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)
	c1.layout_box:setMargins({10, 20, 10, 20}) -- top, right, bottom, left

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child position should include margin offset
	t:eq(c1.layout_box.x.pos, 20) -- left margin
	t:eq(c1.layout_box.y.pos, 10) -- top margin
end

---@param t testing.T
function test.flex_row_margins_affect_container_size(t)
	local root = new_node()
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setWidthAuto()
	root.layout_box:setHeightAuto()

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)
	c1.layout_box:setMargins({10, 20, 10, 20}) -- top, right, bottom, left

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Container size should include child margins
	-- width = child + left_margin + right_margin = 50 + 20 + 20 = 90
	-- height = child + top_margin + bottom_margin = 50 + 10 + 10 = 70
	t:eq(root.layout_box.x.size, 90)
	t:eq(root.layout_box.y.size, 70)
end

-------------------------------------------------------------------------------
-- AlignItems with Padding and Margins Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.align_items_end_with_padding(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left
	root.layout_box:setAlignItems(LayoutBox.AlignItems.End)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 30)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child should be positioned at bottom of content area
	-- Available height = 100 - 10 (top padding) - 10 (bottom padding) = 80
	-- y.pos = top_padding + available_height - child_height = 10 + 80 - 30 = 60
	t:eq(c1.layout_box.y.pos, 60)
end

---@param t testing.T
function test.align_items_center_with_padding(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({10, 20, 10, 20}) -- top, right, bottom, left
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Center)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 30)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child should be centered in content area
	-- Available height = 100 - 10 - 10 = 80
	-- y.pos = top_padding + (available_height - child_height) / 2 = 10 + (80 - 30) / 2 = 35
	t:eq(c1.layout_box.y.pos, 35)
end

---@param t testing.T
function test.align_items_end_with_margins(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.End)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 30)
	c1.layout_box:setMargins({5, 10, 5, 10}) -- top, right, bottom, left

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child should be positioned at end accounting for margins
	-- y.pos = container_height - child_height - margin_bottom = 100 - 30 - 5 = 65
	t:eq(c1.layout_box.y.pos, 65)
end

---@param t testing.T
function test.align_items_center_with_margins(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Center)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 30)
	c1.layout_box:setMargins({5, 10, 5, 10}) -- top, right, bottom, left

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child should be centered accounting for margins
	-- Available height = 100
	-- Space needed = child_height + margin_top + margin_bottom = 30 + 5 + 5 = 40
	-- y.pos = (available - space_needed) / 2 + margin_top = (100 - 40) / 2 + 5 = 35
	t:eq(c1.layout_box.y.pos, 35)
end

-------------------------------------------------------------------------------
-- AlignItems.Stretch with Margins Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.align_items_stretch_with_margins(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(50)
	c1.layout_box:setHeightAuto()
	c1.layout_box:setMargins({10, 0, 10, 0}) -- top, right, bottom, left (only top/bottom)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child should stretch to fill available space minus margins
	-- stretched_size = container_height - margin_top - margin_bottom = 100 - 10 - 10 = 80
	t:eq(c1.layout_box.y.size, 80)
end

---@param t testing.T
function test.align_items_stretch_with_padding_and_margins(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({10, 10, 10, 10}) -- top, right, bottom, left
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(50)
	c1.layout_box:setHeightAuto()
	c1.layout_box:setMargins({5, 0, 5, 0}) -- top, right, bottom, left

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Available height = 100 - 10 - 10 = 80 (container minus padding)
	-- Stretched size = 80 - 5 - 5 = 70 (available minus margins)
	t:eq(c1.layout_box.y.size, 70)
end

---@param t testing.T
function test.align_items_stretch_zero_container_size(t)
	-- Test that cross-axis stretch works even when container size is exactly 0
	-- This was a bug: available_space ~= 0 check skipped stretch when size was 0
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(0) -- Container height is 0
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(50)
	c1.layout_box:setHeightAuto() -- Should stretch to 0

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Child should be stretched to 0 (container height minus margins)
	t:eq(c1.layout_box.y.size, 0, "child should stretch to 0 when container is 0")
end

-------------------------------------------------------------------------------
-- JustifyContent with Padding Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.justify_content_center_with_padding(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({0, 20, 0, 20}) -- top, right, bottom, left
	root.layout_box:setJustifyContent(LayoutBox.JustifyContent.Center)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Available width = 200 - 20 - 20 = 160
	-- x.pos = left_padding + (available_width - child_width) / 2 = 20 + (160 - 50) / 2 = 75
	t:eq(c1.layout_box.x.pos, 75)
end

---@param t testing.T
function test.justify_content_end_with_padding(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({0, 20, 0, 20}) -- top, right, bottom, left
	root.layout_box:setJustifyContent(LayoutBox.JustifyContent.End)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- x.pos = container_width - right_padding - child_width = 200 - 20 - 50 = 130
	t:eq(c1.layout_box.x.pos, 130)
end

---@param t testing.T
function test.justify_content_space_between_with_padding(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setPaddings({0, 20, 0, 20}) -- top, right, bottom, left
	root.layout_box:setJustifyContent(LayoutBox.JustifyContent.SpaceBetween)

	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = root:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Available width = 200 - 20 - 20 = 160
	-- Total children width = 50 + 50 = 100
	-- Gap = (160 - 100) / (2 - 1) = 60
	-- c1.x.pos = left_padding = 20
	-- c2.x.pos = 20 + 50 + 60 = 130
	t:eq(c1.layout_box.x.pos, 20)
	t:eq(c2.layout_box.x.pos, 130)
end

-------------------------------------------------------------------------------
-- Shrink Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.shrink_proportional(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(150)
	c1.layout_box:setGrow(1)

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(150)
	c2.layout_box:setGrow(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Total width needed: 150 + 150 = 300
	-- Available: 200
	-- Shrink by: 100
	-- Each shrinks by 50 (proportional to grow factor)
	t:eq(c1.layout_box.x.size, 100)
	t:eq(c2.layout_box.x.size, 100)
end

---@param t testing.T
function test.shrink_with_min_size(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	local c1 = root:add(new_node())
	c1.layout_box:setWidth(150)
	c1.layout_box:setShrink(1)
	c1.layout_box.x:setMin(120) -- min_size = 120

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(150)
	c2.layout_box:setShrink(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Total width needed: 150 + 150 = 300
	-- Available: 200
	-- Shrink by: 100
	-- c1 can only shrink to 120 (shrinks by 30)
	-- c2 must shrink by remaining 70 -> 150 - 70 = 80
	t:eq(c1.layout_box.x.size, 120)
	t:eq(c2.layout_box.x.size, 80)
end

---@param t testing.T
function test.shrink_factor_proportional(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	-- c1 has shrink=2, c2 has shrink=1
	-- c1 should shrink twice as much as c2
	local c1 = root:add(new_node())
	c1.layout_box:setWidth(150)
	c1.layout_box:setShrink(2)

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(150)
	c2.layout_box:setShrink(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Total width needed: 150 + 150 = 300
	-- Available: 200
	-- Shrink by: 100
	-- total_shrink = 2 + 1 = 3
	-- c1 shrinks by: 100 * (2/3) = 66.67 -> 150 - 66.67 = 83.33
	-- c2 shrinks by: 100 * (1/3) = 33.33 -> 150 - 33.33 = 116.67
	t:aeq(c1.layout_box.x.size, 83.33, 0.1)
	t:aeq(c2.layout_box.x.size, 116.67, 0.1)
end

---@param t testing.T
function test.shrink_scaled_by_size(t)
	-- Test CSS Flexbox behavior: shrink is scaled by base size
	-- This prevents small elements from collapsing when paired with large elements
	local root = new_node()
	root.layout_box:setWidth(990)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	-- c1 is large (1000px), c2 is small (10px), both have shrink=1
	local c1 = root:add(new_node())
	c1.layout_box:setWidth(1000)
	c1.layout_box:setShrink(1)

	local c2 = root:add(new_node())
	c2.layout_box:setWidth(10)
	c2.layout_box:setShrink(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Total width needed: 1000 + 10 = 1010
	-- Available: 990
	-- Shrink by: 20
	-- 
	-- CSS Flexbox uses scaled shrink factor (shrink * base_size):
	-- weight_c1 = 1 * 1000 = 1000
	-- weight_c2 = 1 * 10 = 10
	-- total_weight = 1010
	-- 
	-- c1 shrinks by: 20 * (1000/1010) ≈ 19.8 -> 1000 - 19.8 = 980.2
	-- c2 shrinks by: 20 * (10/1010) ≈ 0.2 -> 10 - 0.2 = 9.8
	-- 
	-- Both shrink by ~2% of their size (proportional)
	-- Old buggy behavior would shrink both by 10px, collapsing c2 to 0px
	t:aeq(c1.layout_box.x.size, 980.2, 0.1)
	t:aeq(c2.layout_box.x.size, 9.8, 0.1)
end

---@param t testing.T
function test.shrink_zero_no_shrink(t)
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	-- c1 has shrink=0, should not shrink
	local c1 = root:add(new_node())
	c1.layout_box:setWidth(150)
	c1.layout_box:setShrink(0)

	-- c2 has shrink=1, should absorb all shrink
	local c2 = root:add(new_node())
	c2.layout_box:setWidth(150)
	c2.layout_box:setShrink(1)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Total width needed: 150 + 150 = 300
	-- Available: 200
	-- Shrink by: 100
	-- c1 has shrink=0, so it stays at 150
	-- c2 has shrink=1, absorbs all 100 -> 150 - 100 = 50
	t:eq(c1.layout_box.x.size, 150)
	t:eq(c2.layout_box.x.size, 50)
end

---@param t testing.T
function test.shrink_nested_flex_container(t)
	-- Scenario: Root with variable dimensions
	-- Flex container with width = 70% and height = 100%
	-- Child with grow in a flex container
	-- Child of a child with width = 100% and height = 100%

	local root = new_node()
	root.layout_box:setWidth(400)
	root.layout_box:setHeight(200)

	-- Flex container with percent sizing
	local flex_container = root:add(new_node())
	flex_container.layout_box:setWidthPercent(0.7)
	flex_container.layout_box:setHeightPercent(1.0)
	flex_container.layout_box:setArrange(LayoutBox.Arrange.FlexRow)

	-- Child with grow
	local growing_child = flex_container:add(new_node())
	growing_child.layout_box:setGrow(1)
	growing_child.layout_box:setHeightAuto()

	-- Grandchild with 100% dimensions
	local grandchild = growing_child:add(new_node())
	grandchild.layout_box:setWidthPercent(1.0)
	grandchild.layout_box:setHeightPercent(1.0)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Initial layout
	-- Flex container: 70% of 400 = 280 width, 100% of 200 = 200 height
	t:eq(flex_container.layout_box.x.size, 280)
	t:eq(flex_container.layout_box.y.size, 200)
	-- Growing child should fill the flex container
	t:eq(growing_child.layout_box.x.size, 280)
	-- Grandchild should be 100% of growing_child
	t:eq(grandchild.layout_box.x.size, 280)

	-- Now shrink the root
	root.layout_box:setWidth(200)
	engine:updateLayout(root.children)

	-- After shrinking:
	-- Flex container: 70% of 200 = 140 width
	t:eq(flex_container.layout_box.x.size, 140)
	-- Growing child should shrink to fit
	t:eq(growing_child.layout_box.x.size, 140)
	-- Grandchild should also shrink
	t:eq(grandchild.layout_box.x.size, 140)
end

-------------------------------------------------------------------------------
-- Gap with Percent Children Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.gap_with_percent_children(t)
	-- Test that gap is calculated correctly when mixing Percent and non-Percent children
	-- This tests the fix for double gap calculation bug
	local root = new_node()
	root.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	root.layout_box:setWidthAuto()
	root.layout_box:setHeight(100)
	root.layout_box.child_gap = 10

	-- Two fixed-width children
	local c1 = root:add(new_node())
	c1.layout_box:setDimensions(50, 50)

	local c2 = root:add(new_node())
	c2.layout_box:setDimensions(50, 50)

	-- One percent-width child
	local c3 = root:add(new_node())
	c3.layout_box:setWidthPercent(0.5) -- 50% of container
	c3.layout_box:setHeight(50)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- Expected calculation:
	-- First pass: c1=50, c2=50, s=100, child_count=2
	-- Preliminary container size = 100 (for percent child to reference)
	-- Second pass: c3 = 50% of 100 = 50, s=150, child_count=3
	-- Gap: 10 * (3-1) = 20
	-- Final: 150 + 20 = 170
	t:eq(root.layout_box.x.size, 170, "container width with gap and percent child")
end

-------------------------------------------------------------------------------
-- Nested Flex Container Tests
-------------------------------------------------------------------------------

---@param t testing.T
function test.nested_flex_col_stretch_propagation(t)
	-- This test verifies that stretch propagates through nested flex containers
	-- With the new default align_items=Stretch, children should stretch automatically
	
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexCol)
	-- align_items defaults to Stretch now

	-- c1: flex_col (align_items defaults to Stretch)
	local c1 = root:add(new_node())
	c1.layout_box:setArrange(LayoutBox.Arrange.FlexCol)
	c1.layout_box:setHeight(50)

	-- c2: flex_row (align_items defaults to Stretch)
	local c2 = c1:add(new_node())
	c2.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	c2.layout_box:setHeight(30)

	-- label: fixed size (simulating intrinsic size)
	local label = c2:add(new_node())
	label.layout_box:setDimensions(100, 20)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	-- With default Stretch, all containers should stretch to parent width
	t:eq(c1.layout_box.x.size, 200, "c1 stretches to root width")
	t:eq(c2.layout_box.x.size, 200, "c2 stretches to c1 width (default Stretch)")
	
	-- Now simulate window resize
	root.layout_box:setWidth(300)
	engine:updateLayout(root.children)
	
	t:eq(c1.layout_box.x.size, 300, "c1 stretches to new root width")
	t:eq(c2.layout_box.x.size, 300, "c2 stretches to new c1 width")
end

---@param t testing.T
function test.nested_flex_col_with_align_items_start(t)
	-- Test that explicitly setting align_items=Start prevents stretching
	local root = new_node()
	root.layout_box:setWidth(200)
	root.layout_box:setHeight(100)
	root.layout_box:setArrange(LayoutBox.Arrange.FlexCol)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Explicitly don't stretch

	-- c1: flex_col with Start (children won't stretch)
	local c1 = root:add(new_node())
	c1.layout_box:setArrange(LayoutBox.Arrange.FlexCol)
	c1.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	c1.layout_box:setHeight(50)

	-- c2: flex_row
	local c2 = c1:add(new_node())
	c2.layout_box:setArrange(LayoutBox.Arrange.FlexRow)
	c2.layout_box:setHeight(30)

	-- label
	local label = c2:add(new_node())
	label.layout_box:setDimensions(100, 20)

	local engine = LayoutEngine(root)
	engine:updateLayout(root.children)

	t:eq(c1.layout_box.x.size, 100, "c1 uses intrinsic size (not stretched)")
	t:eq(c2.layout_box.x.size, 100, "c2 uses intrinsic size (not stretched)")
end

---@param t testing.T
function test.flex_row_basic_positions(t)
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
function test.flex_col_basic_positions(t)
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
function test.justify_content_positions(t)
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
function test.align_items_cross_axis(t)
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
function test.flex_row_reversed_layout(t)
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
function test.flex_col_reversed_layout(t)
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

return test
