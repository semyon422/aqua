local Message = require("icc.Message")

local test = {}

---@param t testing.T
function test.insert(t)
	local msg = Message(1, false, 3, 4, 5)
	msg:insert("q", 1)
	t:tdeq(msg, Message(1, false, "q", 3, 4, 5))
	msg:insert("w", 3)
	t:tdeq(msg, Message(1, false, "q", 3, "w", 4, 5))
end

return test
