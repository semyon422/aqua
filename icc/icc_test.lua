local Remote = require("icc.Remote")
local RemoteHandler = require("icc.RemoteHandler")
local TaskHandler = require("icc.TaskHandler")
local FakePeer = require("icc.FakePeer")
local Message = require("icc.Message")

local test = {}

---@param t testing.T
function test.all(t)
	local tbl = {}
	tbl.obj = {}
	function tbl.obj:func(remote, a, b)
		return a + b
	end

	local th = TaskHandler(RemoteHandler(tbl))
	local peer = FakePeer()
	local remote = Remote(th, peer)

	local done = false
	coroutine.wrap(function()
		local res = remote.obj:func(1, 2)
		t:eq(res, 3)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(1, nil, {"obj", "func"}, true, 1, 2))

	th:handleCall(peer, peer:get(1))

	t:eq(peer:count(), 2)
	t:tdeq(peer:get(2), Message(1, true, 3))

	th:handleReturn(peer:get(2))

	t:assert(done)
end

return test
