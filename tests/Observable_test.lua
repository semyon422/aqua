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

---@param t testing.T
function test.function_observer(t)
	local observable = Observable()

	local events = {}
	observable:add(function(event)
		table.insert(events, event)
	end)
	observable:add({
		receive = function(_, event)
			table.insert(events, event)
		end,
	})

	observable:send({1})

	t:tdeq(events, {{1}, {1}})
end

return test
