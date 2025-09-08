local ContDepth = require("im.ContDepth")

local test = {}

---@param t testing.T
function test.all(t)
	local cd = ContDepth()

	cd:push("cont1", true)
	t:eq(cd:over(1, true), false)
	cd:pop()
	cd:push("cont2", false)
	t:eq(cd:over(2, true), false)
	cd:pop()
	cd:step()

	cd:push("cont1", true)
	t:eq(cd:over(1, true), true)
	cd:pop()
	cd:push("cont2", false)
	t:eq(cd:over(2, true), false)
	cd:pop()
	cd:step()
end

return test
