local Node = require("ui.Node")
local EventHandler = require("ui.EventHandler")

local test = {}

---@param t testing.T
function test.tree(t)
	local root = Node({event_handler = EventHandler()})
	root:load()

	local n1 = root:add(Node())
	local n2 = n1:add(Node())
	local n3 = n2:add(Node())

	t:teq(root.children, {n1})
	t:teq(n1.children, {n2})
	t:teq(n2.children, {n3})

	n2:kill()
	t:teq(n1.children, {})
	t:teq(n2.children, {})
end

---@param t testing.T
function test.order(t)
	local root = Node({event_handler = EventHandler()})
	root:load()

	local n1 = root:add(Node())
	local n2 = root:add(Node())
	local n3 = root:add(Node())
	local n4 = root:add(Node())
	t:teq(root.children, {n1, n2, n3, n4})

	local n5 = root:add(Node({z = 0.1}))
	t:teq(root.children, {n5, n1, n2, n3, n4})

	local n6 = root:add(Node({z = 0.05}))
	local n7 = root:add(Node({z = 0.2}))
	t:teq(root.children, {n7, n5, n6, n1, n2, n3, n4})
end

return test
