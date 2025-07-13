local Observable = require("Observable")

local test = {}

---@param t testing.T
function test.single(t)
	local observable = Observable()

	local events = {}
	local function receive(self, event)
		table.insert(events, event)
	end

	observable:add({receive = receive})

	observable:receive({1})

	t:tdeq(events, {{1}})
end

---@param t testing.T
function test.multiple(t)
	local observable = Observable()

	local events = {}
	local function receive(self, event)
		table.insert(events, event)
	end

	observable:add({receive = receive})
	observable:add({receive = receive})

	observable:receive({1})
	observable:receive({2})

	t:tdeq(events, {{1}, {1}, {2}, {2}})
end

return test
