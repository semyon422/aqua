local test = {}

-- receiveany will return smaller strings on smaller buffers

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveany_timeout(t, rsoc, ssoc)
	ssoc:send("qwerty")

	t:tdeq({rsoc:receiveany(3)}, {"qwe"})
	t:tdeq({rsoc:receiveany(1)}, {"r"})
	t:tdeq({rsoc:receiveany(3)}, {"ty"})
	t:tdeq({rsoc:receiveany(3)}, {nil, "timeout"})
	t:tdeq({rsoc:receiveany(3)}, {nil, "timeout"})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveany_more_timeout(t, rsoc, ssoc)
	ssoc:send("qwerty")

	t:tdeq({rsoc:receiveany(10)}, {"qwerty"})
	t:tdeq({rsoc:receiveany(10)}, {nil, "timeout"})
	t:tdeq({rsoc:receiveany(10)}, {nil, "timeout"})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveany_closed(t, rsoc, ssoc)
	ssoc:send("qwerty")
	ssoc:close()

	t:tdeq({rsoc:receiveany(3)}, {"qwe"})
	t:tdeq({rsoc:receiveany(1)}, {"r"})
	t:tdeq({rsoc:receiveany(3)}, {"ty"})
	t:tdeq({rsoc:receiveany(3)}, {nil, "closed"})
	t:tdeq({rsoc:receiveany(3)}, {nil, "closed"})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveany_more_closed(t, rsoc, ssoc)
	ssoc:send("qwerty")
	ssoc:close()

	t:tdeq({rsoc:receiveany(10)}, {"qwerty"})
	t:tdeq({rsoc:receiveany(10)}, {nil, "closed"})
	t:tdeq({rsoc:receiveany(10)}, {nil, "closed"})
end

return test
