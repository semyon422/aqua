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

---@param roots {[ui.Node]: boolean}?
---@return integer
local function count_roots(roots)
	local count = 0
	for _ in pairs(roots or {}) do
		count = count + 1
	end
	return count
end

---@param t testing.T
function test.stack_container_auto_size_from_children(t)
	-- Test that a Stack container with Auto size correctly calculates
	-- its size based on children's sizes (max of children)
	local engine = LayoutEngine()
	local container = new_node()
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
function test.stack_with_margins_positioning(t)
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
function test.stack_isolated_sibling_layout(t)
	-- Test optimization: when one sibling changes, other siblings' layouts are not recalculated
	-- Structure:
	--   Root (800x600, Stack)
	--     └── ScreenContainer (100% x 100%, Stack)
	--           └── Screen (100% x 100%, Stack)
	--                 ├── Container A (64px x 100%, WrapRow) - should NOT be remeasured
	--                 │     └── Item A1, Item A2 (fixed size)
	--                 └── Container B (Auto x Auto, Stack) - contains changing child
	--                       └── Child B (changes from 50x50 to 100x100)

	local engine = LayoutEngine()
	local measure_counts = {}

	-- Wrap the engine's measure function to track calls
	local original_measure = engine.measure
	engine.measure = function(self, node, axis_idx)
		local key = tostring(node) .. (axis_idx == LayoutBox.Axis.X and ".x" or ".y")
		measure_counts[key] = (measure_counts[key] or 0) + 1
		return original_measure(self, node, axis_idx)
	end

	-- 1) Root with fixed size (Stack arrange)
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.Stack

	-- 2) Screen container with 100% width and height of the root (Stack arrange)
	local screen_container = root:add(new_node())
	screen_container.layout_box:setWidthPercent(1.0)
	screen_container.layout_box:setHeightPercent(1.0)
	screen_container.layout_box.arrange = LayoutBox.Arrange.Stack

	-- 3) Screen with 100% width and height of the root (Stack arrange)
	local screen = screen_container:add(new_node())
	screen.layout_box:setWidthPercent(1.0)
	screen.layout_box:setHeightPercent(1.0)
	screen.layout_box.arrange = LayoutBox.Arrange.Stack
	screen.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch children
	screen.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	-- 4) Container A: WrapRow with 64px width and 100% height
	local container_a = screen:add(new_node())
	container_a.layout_box:setWidth(64)
	container_a.layout_box:setHeightPercent(1.0)
	container_a.layout_box.arrange = LayoutBox.Arrange.WrapRow

	-- Add some items inside Container A
	local item_a1 = container_a:add(new_node())
	item_a1.layout_box:setDimensions(30, 30)

	local item_a2 = container_a:add(new_node())
	item_a2.layout_box:setDimensions(30, 30)

	-- 5) Container B: Auto size Stack with a child that will change size
	local container_b = screen:add(new_node())
	container_b.layout_box:setWidthAuto()
	container_b.layout_box:setHeightAuto()
	container_b.layout_box.arrange = LayoutBox.Arrange.Stack

	local child_b = container_b:add(new_node())
	child_b.layout_box:setDimensions(50, 50)

	-- First layout pass
	engine:updateLayout(root.children)

	-- Verify initial layout
	t:eq(container_a.layout_box.x.size, 64, "Container A width should be 64")
	t:eq(container_a.layout_box.y.size, 600, "Container A height should be 600 (100% of screen)")
	t:eq(item_a1.layout_box.x.size, 30, "Item A1 width should be 30")
	t:eq(item_a2.layout_box.x.size, 30, "Item A2 width should be 30")
	t:eq(container_b.layout_box.x.size, 50, "Container B width should be 50 (from child)")
	t:eq(container_b.layout_box.y.size, 50, "Container B height should be 50 (from child)")

	-- Reset measure counts
	measure_counts = {}

	-- Change Child B's size
	child_b.layout_box:setDimensions(100, 100)

	-- Second layout pass - only child_b and its ancestors should be remeasured
	local roots = engine:updateLayout({child_b})

	-- Verify new layout
	t:eq(container_b.layout_box.x.size, 100, "Container B width should be 100 after child resize")
	t:eq(container_b.layout_box.y.size, 100, "Container B height should be 100 after child resize")

	-- Layout should stop at the first fixed/percent boundary ancestor.
	t:eq(count_roots(roots), 1, "only one layout root should be selected")
	t:assert(roots[screen], "screen should be the only allowed layout root")
	t:assert(not roots[root], "root should not be selected as a layout root")
	t:assert(not roots[screen_container], "screen container should not be selected as a layout root")
	t:assert(not roots[container_b], "auto subtree should not be selected as a layout root")

	-- Container A and its items should NOT have been remeasured
	-- They should not appear in measure_counts at all, or should have 0 counts
	local container_a_measures = (measure_counts[tostring(container_a) .. ".x"] or 0) +
		(measure_counts[tostring(container_a) .. ".y"] or 0)
	local item_a1_measures = (measure_counts[tostring(item_a1) .. ".x"] or 0) +
		(measure_counts[tostring(item_a1) .. ".y"] or 0)
	local item_a2_measures = (measure_counts[tostring(item_a2) .. ".x"] or 0) +
		(measure_counts[tostring(item_a2) .. ".y"] or 0)

	t:eq(container_a_measures, 0, "Container A should NOT be remeasured when sibling changes")
	t:eq(item_a1_measures, 0, "Item A1 should NOT be remeasured when sibling changes")
	t:eq(item_a2_measures, 0, "Item A2 should NOT be remeasured when sibling changes")

	-- Container A items should retain their original sizes
	t:eq(item_a1.layout_box.x.size, 30, "Item A1 width should remain unchanged")
	t:eq(item_a2.layout_box.x.size, 30, "Item A2 width should remain unchanged")
end

return test
