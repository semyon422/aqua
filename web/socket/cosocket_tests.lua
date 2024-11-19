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

	t:tdeq({coroutine.resume(co)}, {true, "read"})
	t:tdeq({coroutine.resume(co)}, {true})

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

	t:tdeq({coroutine.resume(co)}, {true, "read"})
	t:tdeq({coroutine.resume(co)}, {true})

	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, "qwerty")
end

return test
