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
function test.flow_h_basic(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlowH

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
function test.flow_v_basic(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box.arrange = LayoutBox.Arrange.FlowV

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
	container.layout_box.arrange = LayoutBox.Arrange.FlowH

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
	container.layout_box.arrange = LayoutBox.Arrange.FlowH

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
	container.layout_box.arrange = LayoutBox.Arrange.FlowH

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
function test.flow_h_reversed(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setArrange(LayoutBox.Arrange.FlowH)
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
function test.flow_v_reversed(t)
	local engine = LayoutEngine()
	local container = new_node()
	container.layout_box:setArrange(LayoutBox.Arrange.FlowV)
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
