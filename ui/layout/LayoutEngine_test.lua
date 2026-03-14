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

---@param size {width: number, height: number}
---@return ui.Node
local function new_mutable_intrinsic_node(size)
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
				return size.width
			else
				return size.height
			end
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

---@param engine ui.LayoutEngine
---@return {[string]: integer}
local function instrument_measures(engine)
	local measure_counts = {}
	local original_measure = engine.measure

	engine.measure = function(self, node, axis_idx, dependency_dirty)
		local measured = original_measure(self, node, axis_idx, dependency_dirty)
		if measured then
			local suffix = (axis_idx == Axis.X) and ".x" or ".y"
			local key = tostring(node) .. suffix
			measure_counts[key] = (measure_counts[key] or 0) + 1
		end
		return measured
	end

	return measure_counts
end

---@param measure_counts {[string]: integer}
---@param node ui.Node
---@return integer
local function measure_total(measure_counts, node)
	return (measure_counts[tostring(node) .. ".x"] or 0) + (measure_counts[tostring(node) .. ".y"] or 0)
end

---@param measure_counts {[string]: integer}
local function reset_measure_counts(measure_counts)
	for key in pairs(measure_counts) do
		measure_counts[key] = nil
	end
end

---@param t testing.T
function test.percent_size(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 200)
	container.layout_box.arrange = LayoutBox.Arrange.FlowRow

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
function test.margins(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setDimensions(200, 200)
	container.layout_box.arrange = LayoutBox.Arrange.FlowRow

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
	container.layout_box.arrange = LayoutBox.Arrange.FlowRow

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
	container.layout_box.arrange = LayoutBox.Arrange.FlowRow
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
function test.intrinsic_size_container_sizing(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlowRow
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
function test.percent_child_with_changing_intrinsic_size(t)
	-- Test that parent with Auto height correctly shrinks when intrinsic child shrinks
	-- This tests the fix for the bug where Percent children used stale parent size
	-- Root (FlowRow, 100% width)
	--   └── container (Stack, Auto height)
	--         ├── percent_child (100% height - should follow container)
	--         └── intrinsic_child (Auto - determines container size)
	local engine = LayoutEngine()

	-- Root with fixed dimensions
	local root = new_node()
	root.layout_box:setDimensions(200, 200)
	root.layout_box.arrange = LayoutBox.Arrange.FlowRow
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
function test.intrinsic_size_after_parent_resize(t)
	-- This test reproduces the bug where a Label stays wrapped after parent is resized
	-- Root (FlowCol, fixed size)
	--   Row (FlowRow, Auto size)
	--     Panel (Stack, Auto size, padding)
	--       Label (intrinsic size)
	local engine = LayoutEngine()

	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.FlowCol
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch children

	local row = root:add(new_node())
	row.layout_box.arrange = LayoutBox.Arrange.FlowRow
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
function test.stable_root_stops_at_fixed_percent_boundary(t)
	-- Optimization test: findStableRoot should stop at Fixed/Percent containers
	-- Hierarchy: Root(Fixed) -> Screen(100%) -> Select(100%) -> Label(Auto)
	-- When Label changes, layout root should be Select, not Root
	local engine = LayoutEngine()

	-- Root with fixed dimensions
	local root = new_node()
	root.layout_box:setDimensions(800, 600)

	-- Screen: 100% size (Percent mode - acts as a barrier)
	local screen = root:add(new_node())
	screen.layout_box:setWidthPercent(1.0)
	screen.layout_box:setHeightPercent(1.0)
	screen.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch children

	-- Select: 100% size (Percent mode - also a barrier)
	local select = screen:add(new_node())
	select.layout_box:setWidthPercent(1.0)
	select.layout_box:setHeightPercent(1.0)
	select.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch children

	-- Label: Auto size (intrinsic)
	local label = select:add(new_node_with_intrinsic_size(100, 20))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	-- First layout from root to establish sizes
	engine:updateLayout({root})

	-- All nodes should be measured on first layout
	t:eq(label.layout_box.x.size, 100, "label should have intrinsic width")
	t:eq(select.layout_box.x.size, 800, "select should have 100% of root width")
	t:eq(screen.layout_box.x.size, 800, "screen should have 100% of root width")

	-- Simulate label text change (mark label dirty)
	label.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 150 -- Width changed from 100 to 150
		else
			return 20
		end
	end
	label.layout_box:markDirty(Axis.Both)

	-- Second layout - only label changed
	-- With optimization: layout root should be Select, not Root
	local roots = engine:updateLayout({label})
	---@cast roots -?

	-- Verify label has new size
	t:eq(label.layout_box.x.size, 150, "label should have new intrinsic width")
	t:eq(select.layout_box.x.size, 800, "select size should not change (still 100%)")

	t:eq(count_roots(roots), 1, "only one layout root should be selected")
	t:assert(roots[select], "select should be the first fixed/percent ancestor root")
	t:assert(not roots[screen], "screen should not be selected when select is already stable")
	t:assert(not roots[root], "root should not be selected as the layout root")
end

---@param t testing.T
function test.percent_child_stable_parent_no_propagation(t)
	-- Test: Percent child inside Fixed/Percent parent should not cause upward propagation
	-- when the child's size is recomputed
	local engine = LayoutEngine()

	-- Fixed root
	local root = new_node()
	root.layout_box:setDimensions(400, 300)
	root.layout_box.arrange = LayoutBox.Arrange.FlowRow

	-- Container: Fixed size (stable)
	local container = root:add(new_node())
	container.layout_box:setDimensions(200, 150)
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	-- Percent child: 50% of container
	local percent_child = container:add(new_node())
	percent_child.layout_box:setWidthPercent(0.5)
	percent_child.layout_box:setHeightPercent(0.5)

	-- Initial layout
	engine:updateLayout({percent_child})
	t:eq(percent_child.layout_box.x.size, 100, "percent child should be 50% of 200")
	t:eq(percent_child.layout_box.y.size, 75, "percent child should be 50% of 150")

	-- Mark percent child dirty (simulating a re-layout scenario)
	percent_child.layout_box:markDirty(Axis.Both)

	-- Re-layout - should not propagate above container
	local roots = engine:updateLayout({percent_child})
	---@cast roots -?

	-- Verify size is still correct
	t:eq(percent_child.layout_box.x.size, 100, "percent child should still be 50% of 200")
	t:eq(percent_child.layout_box.y.size, 75, "percent child should still be 50% of 150")
	t:eq(count_roots(roots), 1, "only one layout root should be selected")
	t:assert(roots[container], "fixed parent should be the layout root")
	t:assert(not roots[root], "root should not be selected when fixed parent is stable")
end

---@param t testing.T
function test.auto_stack_child_resize_reflows_flow_siblings(t)
	local engine = LayoutEngine()

	local root = new_node()
	root.layout_box:setDimensions(1000, 400)
	root.layout_box.arrange = LayoutBox.Arrange.FlowRow
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local row = root:add(new_node())
	row.layout_box.arrange = LayoutBox.Arrange.FlowRow
	row.layout_box:setWidthAuto()
	row.layout_box:setHeightAuto()
	row.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	row.layout_box:setChildGap(10)

	local mutable_size = {width = 60, height = 20}

	local tag = row:add(new_node())
	tag.layout_box:setWidthAuto()
	tag.layout_box:setHeightAuto()
	tag.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)
	tag.layout_box:setPaddings({5, 20, 5, 20})

	local label = tag:add(new_mutable_intrinsic_node(mutable_size))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	local sibling = row:add(new_node_with_intrinsic_size(40, 20))
	sibling.layout_box:setWidthAuto()
	sibling.layout_box:setHeightAuto()

	engine:updateLayout({root})

	local initial_tag_width = tag.layout_box.x.size
	local initial_row_width = row.layout_box.x.size
	local initial_sibling_x = sibling.layout_box.x.pos

	mutable_size.width = 180
	label.layout_box:markDirty(Axis.Both)

	engine:updateLayout({label})

	t:eq(tag.layout_box.x.size, 220, "stack wrapper should grow with its label")
	t:eq(row.layout_box.x.size, 270, "flow row should include updated child width and gap")
	t:eq(sibling.layout_box.x.pos, 230, "sibling should be repositioned after the tag grows")
	t:assert(tag.layout_box.x.size > initial_tag_width, "tag width should increase")
	t:assert(row.layout_box.x.size > initial_row_width, "row width should increase")
	t:assert(sibling.layout_box.x.pos > initial_sibling_x, "sibling position should increase")
end

---@param t testing.T
function test.auto_subtree_under_percent_boundary_skips_clean_sibling_subtrees(t)
	local engine = LayoutEngine()
	local measure_counts = instrument_measures(engine)

	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	root.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local screen = root:add(new_node())
	screen.layout_box:setWidthPercent(1.0)
	screen.layout_box:setHeightPercent(1.0)
	screen.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	screen.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local dirty_container = screen:add(new_node())
	dirty_container.layout_box:setWidthAuto()
	dirty_container.layout_box:setHeightAuto()
	dirty_container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	dirty_container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local dirty_leaf = dirty_container:add(new_node_with_intrinsic_size(80, 40))
	dirty_leaf.layout_box:setWidthAuto()
	dirty_leaf.layout_box:setHeightAuto()

	local clean_container = screen:add(new_node())
	clean_container.layout_box:setWidth(120)
	clean_container.layout_box:setHeightPercent(1.0)
	clean_container.layout_box.arrange = LayoutBox.Arrange.FlowRow

	local clean_item_a = clean_container:add(new_node())
	clean_item_a.layout_box:setDimensions(30, 30)

	local clean_item_b = clean_container:add(new_node())
	clean_item_b.layout_box:setDimensions(30, 30)

	engine:updateLayout({root})
	reset_measure_counts(measure_counts)

	dirty_leaf.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 140
		end
		return 90
	end
	dirty_leaf.layout_box:markDirty(Axis.Both)

	local roots = engine:updateLayout({dirty_leaf})
	---@cast roots -?

	t:eq(dirty_container.layout_box.x.size, 140, "auto container should resize to changed child width")
	t:eq(dirty_container.layout_box.y.size, 90, "auto container should resize to changed child height")
	t:eq(count_roots(roots), 1, "only one layout root should be selected")
	t:assert(roots[screen], "percent boundary ancestor should be selected as layout root")
	t:eq(measure_total(measure_counts, clean_container), 0, "clean sibling container should not be remeasured")
	t:eq(measure_total(measure_counts, clean_item_a), 0, "clean sibling subtree leaf A should not be remeasured")
	t:eq(measure_total(measure_counts, clean_item_b), 0, "clean sibling subtree leaf B should not be remeasured")
end

---@param t testing.T
function test.percent_sized_clean_sibling_not_measured_when_parent_size_is_unchanged(t)
	local engine = LayoutEngine()
	local measure_counts = instrument_measures(engine)

	local root = new_node()
	root.layout_box:setDimensions(640, 480)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	root.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local screen = root:add(new_node())
	screen.layout_box:setWidthPercent(1.0)
	screen.layout_box:setHeightPercent(1.0)
	screen.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	screen.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local auto_container = screen:add(new_node())
	auto_container.layout_box:setWidthAuto()
	auto_container.layout_box:setHeightAuto()
	auto_container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	auto_container.layout_box:setJustifyContent(LayoutBox.JustifyContent.Start)

	local dirty_leaf = auto_container:add(new_node_with_intrinsic_size(120, 80))
	dirty_leaf.layout_box:setWidthAuto()
	dirty_leaf.layout_box:setHeightAuto()

	local percent_sibling = screen:add(new_node())
	percent_sibling.layout_box:setWidthPercent(0.5)
	percent_sibling.layout_box:setHeightPercent(1.0)

	local percent_leaf = percent_sibling:add(new_node())
	percent_leaf.layout_box:setWidthPercent(1.0)
	percent_leaf.layout_box:setHeightPercent(0.5)

	engine:updateLayout({root})
	t:eq(percent_sibling.layout_box.x.size, 320, "percent sibling should have initial width from parent")
	t:eq(percent_leaf.layout_box.x.size, 320, "percent leaf should have initial width from sibling")
	reset_measure_counts(measure_counts)

	dirty_leaf.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 180
		end
		return 60
	end
	dirty_leaf.layout_box:markDirty(Axis.Both)

	local roots = engine:updateLayout({dirty_leaf})
	---@cast roots -?

	t:eq(auto_container.layout_box.x.size, 180, "dirty subtree should update its width")
	t:eq(auto_container.layout_box.y.size, 60, "dirty subtree should update its height")
	t:eq(screen.layout_box.x.size, 640, "screen width should remain unchanged")
	t:eq(screen.layout_box.y.size, 480, "screen height should remain unchanged")
	t:eq(percent_sibling.layout_box.x.size, 320, "clean percent sibling width should remain unchanged")
	t:eq(percent_sibling.layout_box.y.size, 480, "clean percent sibling height should remain unchanged")
	t:eq(percent_leaf.layout_box.x.size, 320, "clean percent descendant width should remain unchanged")
	t:eq(percent_leaf.layout_box.y.size, 240, "clean percent descendant height should remain unchanged")
	t:eq(count_roots(roots), 1, "only one layout root should be selected")
	t:assert(roots[screen], "percent boundary ancestor should be selected as layout root")
	t:eq(measure_total(measure_counts, percent_sibling), 0, "clean percent sibling should not be remeasured")
	t:eq(measure_total(measure_counts, percent_leaf), 0, "clean percent sibling subtree should not be remeasured")
end

---@param t testing.T
function test.multiple_dirty_nodes_ancestor_filtering(t)
	-- Test: When multiple dirty nodes map to different sub-roots in the same tree,
	-- only the ancestor should be used as layout root
	local engine = LayoutEngine()

	-- Root (Fixed)
	local root = new_node()
	root.layout_box:setDimensions(800, 600)

	-- Parent (Fixed) - should become the layout root
	local parent = root:add(new_node())
	parent.layout_box:setDimensions(400, 300)

	-- Child 1 (Auto)
	local child1 = parent:add(new_node_with_intrinsic_size(50, 50))
	child1.layout_box:setWidthAuto()
	child1.layout_box:setHeightAuto()

	-- Child 2 (Auto)
	local child2 = parent:add(new_node_with_intrinsic_size(60, 60))
	child2.layout_box:setWidthAuto()
	child2.layout_box:setHeightAuto()

	-- Grandchild of child1
	local grandchild = child1:add(new_node_with_intrinsic_size(20, 20))
	grandchild.layout_box:setWidthAuto()
	grandchild.layout_box:setHeightAuto()

	-- Mark child2 and grandchild as dirty
	-- Without filtering: would create 2 roots (child2 and child1)
	-- With filtering: only parent should be the root
	child2.layout_box:markDirty(Axis.Both)
	grandchild.layout_box:markDirty(Axis.Both)

	local roots = engine:updateLayout({child2, grandchild})
	---@cast roots -?

	-- Count roots
	local root_count = 0
	for _ in pairs(roots) do root_count = root_count + 1 end

	-- Should only have 1 root (parent), not 2 (child1 and child2)
	t:eq(root_count, 1, "should have only 1 layout root (parent)")
	t:assert(roots[parent], "parent should be the layout root")
	t:assert(not roots[child1], "child1 should not be a separate root")
	t:assert(not roots[child2], "child2 should not be a separate root")
end

---@param t testing.T
function test.multiple_disconnected_roots_are_preserved(t)
	local engine = LayoutEngine()

	local root_a = new_node()
	root_a.layout_box:setDimensions(800, 600)
	root_a.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local container_a = root_a:add(new_node())
	container_a.layout_box:setWidthAuto()
	container_a.layout_box:setHeightAuto()
	container_a.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local leaf_a = container_a:add(new_node_with_intrinsic_size(100, 50))
	leaf_a.layout_box:setWidthAuto()
	leaf_a.layout_box:setHeightAuto()

	local root_b = new_node()
	root_b.layout_box:setDimensions(1024, 768)
	root_b.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local container_b = root_b:add(new_node())
	container_b.layout_box:setWidthAuto()
	container_b.layout_box:setHeightAuto()
	container_b.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local leaf_b = container_b:add(new_node_with_intrinsic_size(80, 40))
	leaf_b.layout_box:setWidthAuto()
	leaf_b.layout_box:setHeightAuto()

	engine:updateLayout({root_a, root_b})
	t:eq(container_a.layout_box.x.size, 100)
	t:eq(container_b.layout_box.x.size, 80)

	leaf_a.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 140
		end
		return 70
	end
	leaf_b.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 120
		end
		return 90
	end
	leaf_a.layout_box:markDirty(Axis.Both)
	leaf_b.layout_box:markDirty(Axis.Both)

	local roots = engine:updateLayout({leaf_a, leaf_b})
	---@cast roots -?

	t:eq(container_a.layout_box.x.size, 140, "first disconnected tree should be updated")
	t:eq(container_a.layout_box.y.size, 70, "first disconnected tree should be updated")
	t:eq(container_b.layout_box.x.size, 120, "second disconnected tree should be updated")
	t:eq(container_b.layout_box.y.size, 90, "second disconnected tree should be updated")
	t:eq(count_roots(roots), 2, "both disconnected roots should be kept")
	t:assert(roots[root_a], "first tree root should be selected")
	t:assert(roots[root_b], "second tree root should be selected")
end

---@param t testing.T
function test.auto_parent_still_propagates_up(t)
	-- Test: When parent has Auto size, layout should still propagate up
	-- This ensures we don't break the non-optimized case
	local engine = LayoutEngine()

	-- Root (Fixed)
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start) -- Don't stretch children

	-- Container (Auto) - size depends on children, so should propagate up
	local container = root:add(new_node())
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	-- Child (Auto) - determines container size
	local child = container:add(new_node_with_intrinsic_size(100, 50))
	child.layout_box:setWidthAuto()
	child.layout_box:setHeightAuto()

	-- Initial layout from root
	engine:updateLayout({root})
	t:eq(container.layout_box.x.size, 100, "container should fit child")
	t:eq(container.layout_box.y.size, 50, "container should fit child")

	-- Change child size
	child.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 200
		else
			return 100
		end
	end
	child.layout_box:markDirty(Axis.Both)

	-- Re-layout - should propagate to root because container has Auto size
	local roots = engine:updateLayout({child})
	---@cast roots -?

	-- Container should have new size
	t:eq(container.layout_box.x.size, 200, "container should resize to fit larger child")
	t:eq(container.layout_box.y.size, 100, "container should resize to fit larger child")

	-- Root should be the layout root (since container has Auto size, it propagates up)
	t:assert(roots[root], "root should be the layout root (container has Auto size)")
end

---@param t testing.T
function test.persistent_dirty_state_not_limited_to_input_list(t)
	local engine = LayoutEngine()

	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local container = root:add(new_node())
	container.layout_box:setWidthAuto()
	container.layout_box:setHeightAuto()
	container.layout_box:setAlignItems(LayoutBox.AlignItems.Start)

	local child_a = container:add(new_node_with_intrinsic_size(100, 40))
	child_a.layout_box:setWidthAuto()
	child_a.layout_box:setHeightAuto()

	local child_b = container:add(new_node_with_intrinsic_size(120, 60))
	child_b.layout_box:setWidthAuto()
	child_b.layout_box:setHeightAuto()

	engine:updateLayout({root})
	t:eq(container.layout_box.x.size, 120)
	t:eq(container.layout_box.y.size, 60)

	child_b.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			return 180
		end
		return 90
	end
	child_b.layout_box:markDirty(Axis.Both)

	-- Update from sibling only: engine should still detect dirty descendant via persistent flags.
	engine:updateLayout({child_a})

	t:eq(container.layout_box.x.size, 180, "container width should include dirty sibling")
	t:eq(container.layout_box.y.size, 90, "container height should include dirty sibling")
	t:eq(child_b.layout_box.axis_invalidated, Axis.None, "dirty sibling should be marked valid after layout")
end

---@param t testing.T
function test.resize_propagates_through_percent_chain(t)
	local engine = LayoutEngine()

	local root = new_node()
	root.layout_box:setDimensions(100, 100)

	local level1 = root:add(new_node())
	level1.layout_box:setWidthPercent(1.0)
	level1.layout_box:setHeightPercent(1.0)

	local level2 = level1:add(new_node())
	level2.layout_box:setWidthPercent(1.0)
	level2.layout_box:setHeightPercent(1.0)

	local leaf = level2:add(new_node())
	leaf.layout_box:setWidthPercent(1.0)
	leaf.layout_box:setHeightPercent(1.0)

	engine:updateLayout({root})
	t:eq(level1.layout_box.x.size, 100)
	t:eq(level2.layout_box.x.size, 100)
	t:eq(leaf.layout_box.x.size, 100)

	root.layout_box:setWidth(200)

	-- Only root is marked dirty by window resize. Descendants must still recalculate.
	engine:updateLayout({root})

	t:eq(level1.layout_box.x.size, 200)
	t:eq(level2.layout_box.x.size, 200)
	t:eq(leaf.layout_box.x.size, 200)
end

return test
