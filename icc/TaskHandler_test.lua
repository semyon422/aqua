local TaskHandler = require("icc.TaskHandler")
local FakePeer = require("icc.FakePeer")

local test = {}

function test.basic(t)
	local th = TaskHandler()
	local peer = FakePeer()

	local done = false
	coroutine.wrap(function()
		local res = th:call(peer, 1, 2)
		t:eq(res, 3)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), {
		1, 2,
		n = 2,
		id = 1,
	})

	local function handler(_peer, a, b)
		return a + b
	end

	th:receive(peer.messages[1], peer, handler)

	t:eq(peer:count(), 2)
	t:tdeq(peer:get(2), {
		3,
		n = 1,
		id = 1,
		ret = true,
	})

	th:receive(peer.messages[2], peer, handler)
	t:assert(done)
end

function test.basic_no_return(t)
	local th = TaskHandler()
	local peer = FakePeer()

	local done = false
	coroutine.wrap(function()
		local res = th:callnr(peer, 1, 2)
		t:eq(res, nil)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), {
		1, 2,
		n = 2,
	})

	local handled = false
	local function handler(_peer, a, b)
		handled = true
		return a + b
	end

	th:receive(peer:get(1), peer, handler)

	t:eq(peer:count(), 1)
	t:assert(handled)
	t:assert(done)
end

return test
