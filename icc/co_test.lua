local icc_co = require("icc.co")

local test = {}

---@param t testing.T
function test.pwrap_ok_on_first_resume(t)
	---@type boolean, any
	local ok, err

	local f = icc_co.pwrap(function()
		return "ret"
	end, function(_ok, _err)
		ok, err = _ok, _err
	end)

	t:eq(ok, nil)

	f()
	t:eq(ok, true)
	t:eq(err, "ret")
end

---@param t testing.T
function test.pwrap_ok_on_second_resume(t)
	---@type boolean, any
	local ok, err

	---@type thread
	local co

	local f = icc_co.pwrap(function()
		co = coroutine.running()
		coroutine.yield()
		return "ret"
	end, function(_ok, _err)
		ok, err = _ok, _err
	end)

	t:eq(ok, nil)

	f()
	t:eq(ok, nil)

	assert(coroutine.resume(co))
	t:eq(ok, true)
	t:eq(err, "ret")
end

---@param t testing.T
function test.pwrap_error_on_first_resume(t)
	---@type boolean, any
	local ok, err

	local f = icc_co.pwrap(function()
		error("msg")
		return "ret"
	end, function(_ok, _err)
		ok, err = _ok, _err
	end)

	t:eq(ok, nil)

	f()
	t:eq(ok, false)
	t:assert(err and err:match("_test.lua:%d+: msg"))
	t:assert(err and not err:match("stack traceback"))
end

---@param t testing.T
function test.pwrap_error_on_second_resume(t)
	---@type boolean, any
	local ok, err

	---@type thread
	local co

	local f = icc_co.pwrap(function()
		co = coroutine.running()
		coroutine.yield()
		error("msg")
		return "ret"
	end, function(_ok, _err)
		ok, err = _ok, _err
	end)

	t:eq(ok, nil)

	f()
	t:eq(ok, nil)

	assert(coroutine.resume(co))
	t:eq(ok, false)
	t:assert(err and err:match("_test.lua:%d+: msg"))
	t:assert(err and not err:match("stack traceback"))
end

---@param t testing.T
function test.wrap_iterator(t)
	local iter = icc_co.wrap(function()
		for i = 1, 3 do
			coroutine.yield(i)
		end
	end)

	t:eq(iter(), 1)
	t:eq(iter(), 2)
	t:eq(iter(), 3)
	t:eq(iter(), nil)
	t:has_error(iter)
end

return test
