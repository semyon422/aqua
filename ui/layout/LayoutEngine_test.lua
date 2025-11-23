local LayoutEngine = require("ui.layout.LayoutEngine")
local LayoutBox = require("ui.layout.LayoutBox")

local test = {}

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
	c1.layout_box.width = 100
	c1.layout_box.height = 100

	local c2 = container:add(new_node())
	c2.layout_box.width = 50
	c2.layout_box.height = 100

	local c3 = container:add(new_node())
	c3.layout_box.width = 100
	c3.layout_box.height = 100

	engine:updateLayout(container.children)

	t:eq(c1.layout_box.x, 0)
	t:eq(c2.layout_box.x, 100)
	t:eq(c3.layout_box.x, 150)

	t:eq(c1.layout_box.y, 0)
	t:eq(c2.layout_box.y, 0)
	t:eq(c2.layout_box.y, 0)

	t:eq(c1.layout_box.width, 100)
	t:eq(c1.layout_box.height, 100)

	t:eq(c2.layout_box.width, 50)
	t:eq(c2.layout_box.height, 100)

	t:eq(c3.layout_box.width, 100)
	t:eq(c3.layout_box.height, 100)
end

return test
