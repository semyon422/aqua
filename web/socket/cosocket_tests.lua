local test = {}

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_timeout(t, rsoc, ssoc)
	ssoc:send("qwe")

	---@type string?, "closed"|"timeout", string?
	local data, err, partial
	local co = coroutine.create(function()
		data, err, partial = rsoc:receive(10)
	end)

	t:tdeq({coroutine.resume(co)}, {true, "read"})

	ssoc:send("rty")

	local ok, reason = coroutine.resume(co)
	t:tdeq({ok, reason}, {true, "read"})
	while ok and reason do
		ok, reason = coroutine.resume(co)
	end

	t:eq(data, nil)
	t:eq(err, "timeout")
	t:eq(partial, "qwerty")

	ssoc:close()
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_closed(t, rsoc, ssoc)
	ssoc:send("qwe")

	---@type string?, "closed"|"timeout", string?
	local data, err, partial
	local co = coroutine.create(function()
		data, err, partial = rsoc:receive(10)
	end)

	t:tdeq({coroutine.resume(co)}, {true, "read"})

	ssoc:send("rty")
	ssoc:close()

	local ok, reason = coroutine.resume(co)
	-- t:tdeq({ok, reason}, {true, "read"})
	while ok and reason do
		ok, reason = coroutine.resume(co)
	end

	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, "qwerty")
end

return test
