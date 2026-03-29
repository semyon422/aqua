local FunctionTimer = require("time.FunctionTimer")

local test = {}

---@param t testing.T
function test.get_time(t)
	local current = 0
	local timer = FunctionTimer(function()
		return current
	end)

	t:eq(timer:getTime(), 0)
	current = 12.5
	t:eq(timer:getTime(), 12.5)
end

return test
