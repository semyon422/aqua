local RemoteHandler = require("icc.RemoteHandler")
local TaskHandler = require("icc.TaskHandler")
local FakePeer = require("icc.FakePeer")

local test = {}

function test.basic(t)
	local tbl = {}
	tbl.obj = {}

	tbl.obj.func = function(self, remote, a, b)
		return a + b
	end

	local th = TaskHandler()
	local rh = RemoteHandler:create(th, tbl)

	local peer = FakePeer()
	local res = rh(peer, {"obj", "func"}, true, 1, 2)

	t:eq(res, 3)
end

return test
