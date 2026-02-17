local Node = require("ui.view.Node")

local test = {}

---@param t testing.T
function test.tree(t)
	local root = Node()
	root:load()

	local n1 = root:add(Node())
	local n2 = n1:add(Node())
	local n3 = n2:add(Node())

	t:teq(root.children, {n1})
	t:teq(n1.children, {n2})
	t:teq(n2.children, {n3})
end

---@param t testing.T
function test.order(t)
	local root = Node()
	root:load()

	local n1 = root:add(Node())
	local n2 = root:add(Node())
	local n3 = root:add(Node())
	local n4 = root:add(Node())
	t:teq(root.children, {n1, n2, n3, n4})
end

return test
