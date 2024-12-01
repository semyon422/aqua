local BoundarySocket = require("web.socket.BoundarySocket")

local test = {}

---@param rets table[]
---@return function
local function iter(rets)
	local i = 0
	return function()
		i = i + 1
		local t = rets[i] or rets[#rets]
		return unpack(t)
	end
end

---@param t testing.T
function test.basic_timeout(t)
	local rets = {
		{"qwe"},
		{"rty"},
		{nil, "timeout", "asd"},
		{nil, "timeout", ""},
		{nil, "timeout", ""},
	}

	local soc = BoundarySocket(iter(rets))

	t:tdeq({soc:receiveany(4)}, {"qwe"})
	t:tdeq({soc:receiveany(1)}, {"r"})
	t:tdeq({soc:receiveany(3)}, {"ty"})
	t:tdeq({soc:receiveany(4)}, {nil, "timeout"})
	t:tdeq({soc:receiveany(4)}, {nil, "timeout"})
end

---@param t testing.T
function test.basic_closed(t)
	local rets = {
		{"qwe"},
		{"rty"},
		{nil, "closed", "asd"},
		{nil, "closed", ""},
		{nil, "closed", ""},
	}

	local soc = BoundarySocket(iter(rets))

	t:tdeq({soc:receiveany(4)}, {"qwe"})
	t:tdeq({soc:receiveany(1)}, {"r"})
	t:tdeq({soc:receiveany(3)}, {"ty"})
	t:tdeq({soc:receiveany(4)}, {nil, "closed"})
	t:tdeq({soc:receiveany(4)}, {nil, "closed"})
end

---@param t testing.T
function test.basic_ok(t)
	local rets = {
		{"qwe"},
		{"rty"},
		{},
		{nil, "timeout", "fgh"},
		{nil, "timeout", ""},
		{nil, "timeout", ""},
	}

	local soc = BoundarySocket(iter(rets))

	t:tdeq({soc:receiveany(4)}, {"qwe"})
	t:tdeq({soc:receiveany(4)}, {"rty"})
	t:tdeq({soc:receiveany(4)}, {nil, "closed"})
	t:tdeq({soc:receiveany(4)}, {nil, "closed"})
end

return test
