local RemoteHandler = require("icc.RemoteHandler")
local TaskHandler = require("icc.TaskHandler")
local FakePeer = require("icc.FakePeer")

local test = {}

---@param t testing.T
function test.basic(t)
	local tbl = {}
	tbl.obj = {}

	tbl.obj.func = function(self, remote, a, b)
		return a + b
	end

	local th = TaskHandler()
	local rh = RemoteHandler(tbl)

	local peer = FakePeer()
	local res = rh:handle(th, peer, {"obj", "func"}, true, 1, 2)

	t:eq(res, 3)
end

---@param t testing.T
function test.whitelist(t)
	local tbl = {}
	tbl.obj = {}
	tbl.obj_hidden = {}

	tbl.obj.func = function() return 1 end
	tbl.obj.func_hidden = function() return 2 end
	tbl.obj_hidden.func = function() return 1 end

	---@type icc.RemoteHandlerWhitelist
	local whitelist = {
		obj = {
			func = true,
		},
	}

	local th = TaskHandler()
	local rh = RemoteHandler(tbl, whitelist)

	local peer = FakePeer()

	t:eq(rh:handle(th, peer, {"obj", "func"}, true), 1)

	local err = t:has_error(rh.handle, rh, th, peer, {"obj_hidden", "func"}, true)
	t:eq(err, "attempt to get field 'obj_hidden' (not whitelisted)")

	local err = t:has_error(rh.handle, rh, th, peer, {"obj", "func_hidden"}, true)
	t:eq(err, "attempt to get field 'func_hidden' (not whitelisted)")
end

---@param t testing.T
function test.error_index_nil(t)
	local tbl = {}

	local th = TaskHandler()
	local rh = RemoteHandler(tbl)

	local peer = FakePeer()

	local err = t:has_error(rh.handle, rh, th, peer, {"obj", "func"}, true)
	t:eq(err, "attempt to index field 'obj' (a nil value)")
end

---@param t testing.T
function test.error_call_nil(t)
	local tbl = {}

	local th = TaskHandler()
	local rh = RemoteHandler(tbl)

	local peer = FakePeer()

	local err = t:has_error(rh.handle, rh, th, peer, {"func"}, true)
	t:eq(err, "attempt to call field 'func' (a nil value)")
end

return test
