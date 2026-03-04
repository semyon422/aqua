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

return test
