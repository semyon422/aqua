local Node = require("ui.Node")
local ITreeRoot = require("ui.ITreeRoot")

local test = {}

---@param t testing.T
function test.tree(t)
	local root = Node({root = ITreeRoot()})
	root:load()

	local n1 = root:addChild(Node())
	local n2 = n1:addChild(Node())
	local n3 = n2:addChild(Node())

	t:teq(root.children, {n1})
	t:teq(n1.children, {n2})
	t:teq(n2.children, {n3})

	n2:kill()
	t:teq(n1.children, {})
	t:teq(n2.children, {})
end

---@param t testing.T
function test.order(t)
	local root = Node({root = ITreeRoot()})
	root:load()

	local n1 = root:addChild(Node())
	local n2 = root:addChild(Node())
	local n3 = root:addChild(Node())
	local n4 = root:addChild(Node())
	t:teq(root.children, {n1, n2, n3, n4})

	local n5 = root:addChild(Node({z = 0.1}))
	t:teq(root.children, {n5, n1, n2, n3, n4})

	local n6 = root:addChild(Node({z = 0.05}))
	local n7 = root:addChild(Node({z = 0.2}))
	t:teq(root.children, {n7, n5, n6, n1, n2, n3, n4})
end

return test
