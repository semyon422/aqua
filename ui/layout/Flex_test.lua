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

return test
