local LayoutBox = require("ui.layout.LayoutBox")
local LayoutEngine = require("ui.layout.LayoutEngine")
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

---@param intrinsic_width number
---@param line_height number
---@return ui.Node
local function new_wrapping_node(intrinsic_width, line_height)
	local node = new_node()
	---@param axis_idx ui.Axis
	---@param constraint number?
	---@return number
	node.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then
			-- Returns full intrinsic width (like unwrapped text)
			return intrinsic_width
		else
			-- Y axis: calculate height based on constraint (wrapping)
			local width = constraint or intrinsic_width
			if width <= 0 then return line_height end
			local lines = math.ceil(intrinsic_width / width)
			return line_height * lines
		end
	end
	return node
end

---@param t testing.T
function test.intrinsic_wrapping_complex(t)
	local engine = LayoutEngine()

	-- Root: fixed size 800x600
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.FlexCol

	-- Intermediate: 50% width (400px), grow 1 (takes remaining height)
	local intermediate = root:add(new_node())
	intermediate.layout_box:setWidthPercent(0.5)
	intermediate.layout_box:setGrow(1)
	intermediate.layout_box.arrange = LayoutBox.Arrange.FlexCol

	-- Leaf: Wrapping node, intrinsic width 1000, line height 20
	-- When constrained to 400px:
	-- lines = ceil(1000 / 400) = 3
	-- height = 3 * 20 = 60
	local leaf = intermediate:add(new_wrapping_node(1000, 20))
	leaf.layout_box:setWidthAuto()
	leaf.layout_box:setHeightAuto()

	-- Case 1: align_items: Start
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	engine:updateLayout({root})

	t:eq(intermediate.layout_box.x.size, 400, "Intermediate should be 50% of 800")
	t:eq(leaf.layout_box.x.size, 400, "Leaf should be constrained to parent width (400)")
	t:eq(leaf.layout_box.y.size, 60, "Leaf should wrap to 3 lines")
	t:eq(leaf.layout_box.x.pos, 0, "Start alignment: x pos should be 0")

	-- Case 2: align_items: Center
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	engine:updateLayout({root})

	t:eq(leaf.layout_box.x.size, 400, "Leaf still constrained to 400")
	t:eq(leaf.layout_box.y.size, 60)
	t:eq(leaf.layout_box.x.pos, 0, "Taking full width, so center pos is 0")

	-- Case 3: align_items: Stretch
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)
	engine:updateLayout({root})

	t:eq(leaf.layout_box.x.size, 400)
	t:eq(leaf.layout_box.y.size, 60)
	t:eq(leaf.layout_box.x.pos, 0)

	-- Test with intrinsic size SMALLER than parent to see alignment difference
	-- Intrinsic width 200. Parent 400.
	leaf.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then return 200 else return 20 end
	end
	leaf.layout_box:markDirty(Axis.Both)

	-- Start alignment with small child
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	engine:updateLayout({root})
	t:eq(leaf.layout_box.x.size, 200, "Should use intrinsic width when unconstrained")
	t:eq(leaf.layout_box.x.pos, 0, "Start alignment: x pos 0")

	-- Center alignment with small child
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	engine:updateLayout({root})
	t:eq(leaf.layout_box.x.size, 200)
	t:eq(leaf.layout_box.x.pos, 100, "Center alignment: (400 - 200) / 2 = 100")

	-- Stretch alignment with small child
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)
	engine:updateLayout({root})
	t:eq(leaf.layout_box.x.size, 400, "Stretch alignment: forced to parent width")
	t:eq(leaf.layout_box.x.pos, 0)
end

---@param t testing.T
function test.intrinsic_wrapping_stack_complex(t)
	local engine = LayoutEngine()

	-- Root: fixed size 800x600
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = LayoutBox.Arrange.FlexCol

	-- Intermediate: 50% width (400px), grow 1
	local intermediate = root:add(new_node())
	intermediate.layout_box:setWidthPercent(0.5)
	intermediate.layout_box:setGrow(1)
	intermediate.layout_box.arrange = LayoutBox.Arrange.Stack

	-- Leaf: Wrapping node, intrinsic width 1000, line height 20
	local leaf = intermediate:add(new_wrapping_node(1000, 20))
	leaf.layout_box:setWidthAuto()
	leaf.layout_box:setHeightAuto()

	-- Case 1: align_items: Start
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Start)
	engine:updateLayout({root})

	t:eq(intermediate.layout_box.x.size, 400, "Intermediate should be 50% of 800")
	t:eq(leaf.layout_box.x.size, 400, "Stack: Leaf should be constrained to parent width (400)")
	t:eq(leaf.layout_box.y.size, 60, "Stack: Leaf should wrap to 3 lines")
	t:eq(leaf.layout_box.x.pos, 0, "Stack Start: x pos 0")

	-- Case 2: align_items: Center
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	engine:updateLayout({root})

	t:eq(leaf.layout_box.x.size, 400, "Stack: Leaf still constrained to 400")
	t:eq(leaf.layout_box.y.size, 60)
	t:eq(leaf.layout_box.x.pos, 0, "Stack Center: pos 0 since it fills width")

	-- Test with smaller intrinsic width
	leaf.getIntrinsicSize = function(self, axis_idx, constraint)
		if axis_idx == Axis.X then return 200 else return 20 end
	end
	leaf.layout_box:markDirty(Axis.Both)

	-- Center alignment with small child in Stack
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Center)
	engine:updateLayout({root})
	t:eq(leaf.layout_box.x.size, 200)
	t:eq(leaf.layout_box.x.pos, 100, "Stack Center: (400 - 200) / 2 = 100")

	-- Stretch alignment in Stack
	intermediate.layout_box:setAlignItems(LayoutBox.AlignItems.Stretch)
	engine:updateLayout({root})
	t:eq(leaf.layout_box.x.size, 400, "Stack Stretch: forced to parent width")
	t:eq(leaf.layout_box.x.pos, 0)
end

---@param t testing.T
function test.button_wrapping_repro(t)
	local engine = LayoutEngine()

	-- Root
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = Enums.Arrange.FlexCol

	-- Button: Fixed width 110, FlexCol, AlignItems Center
	local button = root:add(new_node())
	button.layout_box:setWidth(110)
	button.layout_box:setHeightAuto()
	button.layout_box.arrange = Enums.Arrange.FlexCol
	button.layout_box:setAlignItems(Enums.AlignItems.Center)
	button.layout_box:setPaddings({5, 0, 5, 0}) -- top, right, bottom, left

	-- Icon Label: small
	local icon = button:add(new_wrapping_node(24, 24))
	icon.layout_box:setWidthAuto()
	icon.layout_box:setHeightAuto()

	-- Text Label: Intrinsic width 200 (should wrap to 2 lines in 110px), line height 20
	local label = button:add(new_wrapping_node(200, 20))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	engine:updateLayout({root})

	t:eq(button.layout_box.x.size, 110, "Button width should be 110")
	t:eq(label.layout_box.x.size, 110, "Label width should be constrained to button width")
	t:eq(label.layout_box.y.size, 40, "Label should wrap to 2 lines")
	t:eq(button.layout_box.y.size, 5 + 24 + 20 * 2 + 5, "Button height should be padding + icon + label + padding")
	t:eq(label.layout_box.x.pos, 0, "Label should be at x=0 since it takes full width")
end

---@param t testing.T
function test.zero_available_width_constraint(t)
	local engine = LayoutEngine()

	-- Root
	local root = new_node()
	root.layout_box:setDimensions(800, 600)
	root.layout_box.arrange = Enums.Arrange.FlexCol

	-- Parent: Fixed width 0 (e.g. collapsed)
	local parent = root:add(new_node())
	parent.layout_box:setWidth(0)
	parent.layout_box:setHeightAuto()
	parent.layout_box:setAlignItems(Enums.AlignItems.Center)

	-- Label: Intrinsic width 200
	local label = parent:add(new_wrapping_node(200, 20))
	label.layout_box:setWidthAuto()
	label.layout_box:setHeightAuto()

	engine:updateLayout({root})

	t:eq(parent.layout_box.x.size, 0, "Parent width should be 0")
	t:eq(label.layout_box.x.size, 0, "Label width should be constrained to 0, not 200")
end

return test
