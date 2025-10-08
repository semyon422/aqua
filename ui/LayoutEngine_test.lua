local Node = require("ui.Node")
local Axis = Node.Axis
local LayoutEngine = require("ui.LayoutEngine")

local test = {}

---@return ui.Node root
local function new_root()
	return Node({
		arrange = Node.Arrange.Absolute,
		width_mode = Node.SizeMode.Fit,
		height_mode = Node.SizeMode.Fit,
	})
end

---@param t testing.T
function test.finding_layout_resolver(t)
	local root = Node()
	local engine = LayoutEngine(root)
	t:eq(engine:findLayoutResolver(root, Axis.Both), root)

	local fixed_container = root:add(Node({
		width_mode = Node.SizeMode.Fixed,
		height_mode = Node.SizeMode.Fixed
	}))

	local a = fixed_container:add(Node())
	t:eq(engine:findLayoutResolver(a, Axis.X), fixed_container)

	local mixed_container = fixed_container:add(Node({
		width_mode = Node.SizeMode.Grow,
		height_mode = Node.SizeMode.Fixed,
	}))

	local b = mixed_container:add(Node())
	t:eq(engine:findLayoutResolver(b, Axis.X), fixed_container)
	t:eq(engine:findLayoutResolver(b, Axis.Y), mixed_container)
end

---@param t testing.T
function test.fit_sizing(t)
	-- https://www.figma.com/design/BaNG5kFI2HHoyyzHx2H4UO/Untitled?node-id=0-1&t=EQTwPWhPLVVQYYRR-1

	------ [[ TEST 1 ]] ------
	local root = new_root()
	local engine = LayoutEngine(root)
	root.arrange = Node.Arrange.FlowH

	root:add(Node({
		arrange = Node.Arrange.FlowH,
		width_mode = Node.SizeMode.Fixed,
		height_mode = Node.SizeMode.Fit,
		width = 2,
	}))

	local container = root:add(Node({
		arrange = Node.Arrange.FlowH,
		width_mode = Node.SizeMode.Fit,
		height_mode = Node.SizeMode.Fit,
	}))
	container:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))
	container:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))
	container:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))

	engine:fitX(container)
	engine:fitY(container)
	t:eq(container.width, 3)
	t:eq(container.height, 1)

	engine:fitX(root)
	engine:fitY(root)
	t:eq(root.width, 5)
	t:eq(root.height, 1)

	------ [[ TEST 2 ]] ------
	root = new_root()
	engine = LayoutEngine(root)
	root.arrange = Node.Arrange.FlowH

	local c1 = root:add(Node({
		width_mode = Node.SizeMode.Fit,
		arrange = Node.Arrange.FlowH,
	}))
	c1:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 2
	}))
	c1:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1
	}))

	local c2 = root:add(Node({
		width_mode = Node.SizeMode.Fit,
		arrange = Node.Arrange.FlowH,
	}))
	c2:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1
	}))
	c2:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1
	}))
	c2:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1
	}))

	local c3 = root:add(Node({
		width_mode = Node.SizeMode.Fit,
		arrange = Node.Arrange.FlowH,
	}))
	c3:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 3
	}))

	engine:fitX(root)
	t:eq(root.width, 9)

	------ [[ TEST 3 ]] ------
	root = new_root()
	engine = LayoutEngine(root)
	root.arrange = Node.Arrange.FlowH
	root.child_gap = 5

	c1 = root:add(Node({
		width_mode = Node.SizeMode.Fit,
		height_mode = Node.SizeMode.Fit,
		arrange = Node.Arrange.FlowH,
		padding_left = 5,
		padding_right = 5,
		child_gap = 5
	}))

	c1:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1,
		height = 1
	}))

	c1:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 1,
		height = 1
	}))

	engine:fitX(c1)
	engine:fitY(c1)
	t:eq(c1.width, 17)
	t:eq(c1.height, 1)

	c2 = root:add(Node({
		width_mode = Node.SizeMode.Fit,
		height_mode = Node.SizeMode.Fit,
		arrange = Node.Arrange.FlowV,
		padding_left = 5,
		padding_right = 5,
		child_gap = 5,
	}))

	c2:add(Node({
		width_mode = Node.SizeMode.Fixed,
		height_mode = Node.SizeMode.Fixed,
		width = 2,
		height = 1,
	}))

	c2:add(Node({
		width_mode = Node.SizeMode.Fixed,
		height_mode = Node.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))

	engine:fitX(c2)
	engine:fitY(c2)
	t:eq(c2.width, 12)
	t:eq(c2.height, 7)

	engine:fitX(root)
	engine:fitY(root)
	t:eq(root.width, 34)
	t:eq(root.height, 7)
end

---@param t testing.T
function test.grow_sizing(t)
	-- https://www.figma.com/design/BaNG5kFI2HHoyyzHx2H4UO/Untitled?node-id=0-1&t=EQTwPWhPLVVQYYRR-1

	------ [[ TEST 4 ]] ------
	local root = new_root()
	local engine = LayoutEngine(root)
	root.width_mode = Node.SizeMode.Fixed
	root.width = 10
	root.padding_left = 1
	root.padding_right = 1
	root.child_gap = 1
	root.arrange = Node.Arrange.FlowH

	root:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 2,
	}))

	local grow = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	engine:fitX(root)
	engine:fitY(root)
	engine:grow(root, Axis.X)
	t:eq(grow.width, 5)

	root:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 2,
	}))

	engine:fitX(root)
	engine:fitY(root)
	engine:grow(root, Axis.X)
	t:eq(grow.width, 2)

	------ [[ TEST 5 ]] ------

	root = new_root()
	engine = LayoutEngine(root)
	root.width_mode = Node.SizeMode.Fixed
	root.height_mode = Node.SizeMode.Fixed
	root.width = 10
	root.height = 10
	root.padding_left = 1
	root.padding_top = 1
	root.padding_bottom = 1
	root.padding_right = 1

	local c = root:add(Node({
		width_mode = Node.SizeMode.Grow,
		height_mode = Node.SizeMode.Grow
	}))

	engine:fitX(root)
	engine:fitY(root)
	engine:grow(root, Axis.X)
	engine:grow(root, Axis.Y)
	t:eq(c.width, 8)
	t:eq(c.height, 8)

	------ [[ TEST 6 ]] ------

	root = new_root()
	engine = LayoutEngine(root)
	root.width_mode = Node.SizeMode.Fixed
	root.width = 10
	root.padding_left = 1
	root.padding_right = 1
	root.child_gap = 1
	root.arrange = Node.Arrange.FlowH

	local grow1 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	local grow2 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	engine:fitX(root)
	engine:fitY(root)
	engine:grow(root, Axis.X)
	t:eq(grow1.width, 3.5)
	t:eq(grow2.width, 3.5)

	------ [[ TEST 7 ]] ------

	root = new_root()
	engine = LayoutEngine(root)
	root.width_mode = Node.SizeMode.Fixed
	root.width = 20
	root.padding_left = 1
	root.padding_right = 1
	root.child_gap = 1
	root.arrange = Node.Arrange.FlowH

	root:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 2,
	}))

	grow1 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	grow2 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	root:add(Node({
		width_mode = Node.SizeMode.Fixed,
		width = 3,
	}))

	local grow3 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	engine:fitX(root)
	engine:fitY(root)
	engine:grow(root, Axis.X)
	t:eq(grow1.width, 3)
	t:eq(grow2.width, 3)
	t:eq(grow3.width, 3)

	------ [[ TEST 8 ]] ------

	root = new_root()
	engine = LayoutEngine(root)
	root.width_mode = Node.SizeMode.Fixed
	root.width = 20
	root.padding_left = 1
	root.padding_right = 1
	root.child_gap = 1
	root.arrange = Node.Arrange.FlowH

	-- Min width is 2
	grow1 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))
	grow1:add(Node({
		Node.SizeMode.Fixed,
		width = 2
	}))

	-- Min width is 3
	grow2 = root:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))
	grow2:add(Node({
		Node.SizeMode.Fixed,
		width = 3
	}))

	engine:grow(root, Axis.X)
	t:eq(grow1.width, 8.5)
	t:eq(grow2.width, 8.5)

	------ [[ TEST 9 ]] ------

	root = new_root()
	engine = LayoutEngine(root)
	root.width_mode = Node.SizeMode.Fixed
	root.width = 20
	root.padding_left = 1
	root.padding_right = 1
	root.arrange = Node.Arrange.FlowH

	local container = root:add(Node({
		width_mode = Node.SizeMode.Grow,
		padding_left = 1,
		padding_right = 1,
		child_gap = 1,
		arrange = Node.Arrange.FlowH,
	}))

	local nested_grow1 = container:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	local nested_grow2 = container:add(Node({
		width_mode = Node.SizeMode.Grow,
	}))

	engine:fitX(root)
	engine:fitY(root)
	engine:grow(root, Axis.X)
	t:eq(container.width, 18)
	t:eq(nested_grow1.width, 7.5)
	t:eq(nested_grow2.width, 7.5)
end

return test
