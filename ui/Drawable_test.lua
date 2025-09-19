local Drawable = require("ui.Drawable")

local test = {}

---@return ui.Drawable root
---@return ui.TraversalContext tctx
local function get_ctx()
	local root = Drawable({
		arrange = Drawable.Arrange.Absolute,
		width_mode = Drawable.SizeMode.Fit,
		height_mode = Drawable.SizeMode.Fit,
	})

	local tctx = {
		delta_time = 0,
		mouse_x = 0,
		mouse_y = 0,
		focus_requesters = {}
	}

	return root, tctx
end

---@param t testing.T
function test.fit_sizing(t)
	-- https://www.figma.com/design/BaNG5kFI2HHoyyzHx2H4UO/Untitled?node-id=0-1&t=EQTwPWhPLVVQYYRR-1

	------ [[ TEST 1 ]] ------
	local root, tctx = get_ctx()
	root.arrange = Drawable.Arrange.FlowH

	root:add(Drawable({
		arrange = Drawable.Arrange.FlowH,
		width_mode = Drawable.SizeMode.Fixed,
		height_mode = Drawable.SizeMode.Fit,
		width = 2,
	}))

	local container = root:add(Drawable({
		arrange = Drawable.Arrange.FlowH,
		width_mode = Drawable.SizeMode.Fit,
		height_mode = Drawable.SizeMode.Fit,
	}))
	container:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))
	container:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))
	container:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))

	container:fitX()
	container:fitY()
	t:eq(container:getWidth(), 3)
	t:eq(container:getHeight(), 1)

	root:fitX()
	root:fitY()
	t:eq(root:getWidth(), 5)
	t:eq(root:getHeight(), 1)

	------ [[ TEST 2 ]] ------
	root, tctx = get_ctx()
	root.arrange = Drawable.Arrange.FlowH

	local c1 = root:add(Drawable({
		width_mode = Drawable.SizeMode.Fit,
		arrange = Drawable.Arrange.FlowH,
	}))
	c1:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 2
	}))
	c1:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1
	}))

	local c2 = root:add(Drawable({
		width_mode = Drawable.SizeMode.Fit,
		arrange = Drawable.Arrange.FlowH,
	}))
	c2:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1
	}))
	c2:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1
	}))
	c2:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1
	}))

	local c3 = root:add(Drawable({
		width_mode = Drawable.SizeMode.Fit,
		arrange = Drawable.Arrange.FlowH,
	}))
	c3:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 3
	}))

	root:fitX()
	t:eq(root:getWidth(), 9)

	------ [[ TEST 3 ]] ------
	root, tctx = get_ctx()
	root.arrange = Drawable.Arrange.FlowH
	root.child_gap = 5

	c1 = root:add(Drawable({
		width_mode = Drawable.SizeMode.Fit,
		height_mode = Drawable.SizeMode.Fit,
		arrange = Drawable.Arrange.FlowH,
		padding = { 5, 0, 0, 5 },
		child_gap = 5
	}))

	c1:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1,
		height = 1
	}))

	c1:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 1,
		height = 1
	}))

	c1:fitX()
	c1:fitY()
	t:eq(c1:getWidth(), 17)
	t:eq(c1:getHeight(), 1)

	c2 = root:add(Drawable({
		width_mode = Drawable.SizeMode.Fit,
		height_mode = Drawable.SizeMode.Fit,
		arrange = Drawable.Arrange.FlowV,
		padding = { 5, 0, 0, 5 },
		child_gap = 5,
	}))

	c2:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		height_mode = Drawable.SizeMode.Fixed,
		width = 2,
		height = 1,
	}))

	c2:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		height_mode = Drawable.SizeMode.Fixed,
		width = 1,
		height = 1,
	}))

	c2:fitX()
	c2:fitY()
	t:eq(c2:getWidth(), 12)
	t:eq(c2:getHeight(), 7)

	root:fitX()
	root:fitY()
	t:eq(root:getWidth(), 34)
	t:eq(root:getHeight(), 7)
end

---@param t testing.T
function test.grow_sizing(t)
	-- https://www.figma.com/design/BaNG5kFI2HHoyyzHx2H4UO/Untitled?node-id=0-1&t=EQTwPWhPLVVQYYRR-1

	------ [[ TEST 4 ]] ------
	local root, tctx = get_ctx()
	root.width_mode = Drawable.SizeMode.Fixed
	root.width = 10
	root.padding = { 1, 0, 0, 1 }
	root.child_gap = 1
	root.arrange = Drawable.Arrange.FlowH

	root:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 2,
	}))

	local grow = root:add(Drawable({
		width_mode = Drawable.SizeMode.Grow,
	}))

	root:fitX()
	root:fitY()
	root:growX()
	t:eq(grow:getWidth(), 5)

	root:add(Drawable({
		width_mode = Drawable.SizeMode.Fixed,
		width = 2,
	}))

	root:fitX()
	root:fitY()
	root:growX()
	t:eq(grow:getWidth(), 2)

	root, tctx = get_ctx()
	root.width_mode = Drawable.SizeMode.Fixed
	root.height_mode = Drawable.SizeMode.Fixed
	root.width = 10
	root.height = 10
	root.padding = { 1, 1, 1, 1 }

	------ [[ TEST 5 ]] ------

	local c = root:add(Drawable({
		width_mode = Drawable.SizeMode.Grow,
		height_mode = Drawable.SizeMode.Grow
	}))

	root:fitX()
	root:fitY()
	root:growX()
	root:growY()
	t:eq(c:getWidth(), 8)
	t:eq(c:getHeight(), 8)
end

return test
