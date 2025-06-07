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
end

return test
