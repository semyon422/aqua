local Test = require("testing.Test")
local table_util = require("table_util")

local test = {}

---@param t testing.T
function test.eq_with_message(t)
	local mock_t = Test()
	mock_t:eq(1, 2, "my custom message")
	
	local err = mock_t[1]
	t:assert(err, "should have an error")
	t:assert(err:find("my custom message"), "error should contain custom message")
end

---@param t testing.T
function test.aeq_with_message(t)
	local mock_t = Test()
	mock_t:aeq(1, 2, 0.1, "aeq custom message")
	
	local err = mock_t[1]
	t:assert(err, "should have an error")
	t:assert(err:find("aeq custom message"), "error should contain custom message")
end

---@param t testing.T
function test.tdeq_with_message(t)
	local mock_t = Test()
	mock_t:tdeq({a = 1}, {a = 2}, "tdeq custom message")
	
	local err = mock_t[1]
	t:assert(err, "should have an error")
	t:assert(err:find("tdeq custom message"), "error should contain custom message")
end

return test
