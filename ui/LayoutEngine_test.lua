local Node = require("ui.Node")
local Axis = Node.Axis
local LayoutEngine = require("ui.LayoutEngine")

local test = {}

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

return test
