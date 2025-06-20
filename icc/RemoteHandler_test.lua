local RemoteHandler = require("icc.RemoteHandler")

local test = {}

---@param t testing.T
function test.basic(t)
	local tbl = {}
	tbl.obj = {}

	tbl.obj.func = function(self, a, b)
		t:eq(self.a, 1)
		return a + b
	end

	local rh = RemoteHandler(tbl)
	local ctx = {a = 1}

	local res = rh:handle(ctx, {"obj", "func"}, true, 1, 2)

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

	local rh = RemoteHandler(tbl, whitelist)

	t:eq(rh:handle({}, {"obj", "func"}, true), 1)

	local err = t:has_error(rh.handle, rh, {}, {"obj_hidden", "func"}, true)
	t:eq(err, "attempt to get field 'obj_hidden' (not whitelisted)")

	local err = t:has_error(rh.handle, rh, {}, {"obj", "func_hidden"}, true)
	t:eq(err, "attempt to get field 'func_hidden' (not whitelisted)")
end

---@param t testing.T
function test.error_index_nil(t)
	local tbl = {}

	local rh = RemoteHandler(tbl)

	local err = t:has_error(rh.handle, rh, {}, {"obj", "func"}, true)
	t:eq(err, "attempt to index field 'obj' (a nil value)")
end

---@param t testing.T
function test.error_call_nil(t)
	local tbl = {}

	local rh = RemoteHandler(tbl)

	local err = t:has_error(rh.handle, rh, {}, {"func"}, true)
	t:eq(err, "attempt to call field 'func' (a nil value)")
end

---@param t testing.T
function test.basic_validation(t)
	local tbl = {}
	function tbl:func(a, b)
		return a + b
	end

	local validated = false

	local val = {remote = tbl}
	function val:func(a, b)
		validated = true
		return self.remote:func(a, b)
	end

	local rh = RemoteHandler(val)

	local res = rh:handle({}, {"func"}, true, 1, 2)

	t:eq(res, 3)
	t:assert(validated)
end

return test
