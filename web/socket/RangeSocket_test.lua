local RangeSocket = require("web.socket.RangeSocket")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.basic(t)
	local str_soc = StringSocket()
	local soc = RangeSocket(str_soc)

	t:tdeq({soc:send("")}, {0})
	t:tdeq({soc:send("", 3, 4)}, {2})
	t:tdeq({soc:send("hello", 10, 15)}, {9})
	t:tdeq({soc:send("world", -15, -10)}, {0})
	t:tdeq({soc:send("qwert", -4, -2)}, {4})
	t:tdeq({soc:send("yuiop", -4, 4)}, {4})
	t:tdeq({soc:send("asdfg", -2, 2)}, {3})  -- nothing sent
	t:tdeq({soc:send("hjkl;", -10, 2)}, {2})
	t:tdeq({soc:send("zxcvb", 4, 10)}, {5})

	t:eq(str_soc.remainder, "weruiohjvb")
end

return test
