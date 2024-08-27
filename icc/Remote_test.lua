local Remote = require("icc.Remote")
local TaskHandler = require("icc.TaskHandler")
local FakePeer = require("icc.FakePeer")
local Message = require("icc.Message")

local test = {}

function test.basic(t)
	local th = TaskHandler()
	local peer = FakePeer()
	local remote = Remote(th, peer)

	local done = false
	coroutine.wrap(function()
		local res = remote.obj1.obj2:func1(1, 2)
		t:eq(res, 3)
		done = true
	end)()

	t:tdeq(peer:get(1), Message(1, nil, {"obj1", "obj2", "func1"}, true, 1, 2))

	local function handler(_peer, path, is_method, a, b)
		t:tdeq(path, {"obj1", "obj2", "func1"})
		t:assert(is_method)
		return a + b
	end

	th:handle(peer, peer:get(1), handler)
	th:handleReturn(peer:get(2))
	t:assert(done)
end

return test
