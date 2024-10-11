local test = {}

---@param t testing.T
function test.receive_size_exact(t, rsoc, ssoc)
	ssoc:send("qwe")
	ssoc:close()

	t:tdeq({rsoc:receive(3)}, {"qwe"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_more(t, rsoc, ssoc)
	ssoc:send("qwe")
	ssoc:close()

	t:tdeq({rsoc:receive(4)}, {nil, "closed", "qwe"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_exact_timeout(t, rsoc, ssoc)
	ssoc:send("qwe")

	t:tdeq({rsoc:receive(4)}, {nil, "timeout", "qwe"})

	ssoc:send("rty")
	ssoc:close()

	t:tdeq({rsoc:receive(3)}, {"rty"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_size_prefix(t, rsoc, ssoc)
	ssoc:send("qwerty")

	t:tdeq({rsoc:receive(2, "asd")}, {"asd"})
	t:tdeq({rsoc:receive(3, "asd")}, {"asd"})
	t:tdeq({rsoc:receive(4, "asd")}, {"asdq"})
	t:tdeq({rsoc:receive(5, "asd")}, {"asdwe"})

	ssoc:close()
end

---@param t testing.T
function test.receive_line(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rty")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})

	ssoc:send("asd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive("*l")}, {"rtyasd"})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", "fgh"})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_line_multiple(t, rsoc, ssoc)
	ssoc:send("qwe\r\nrty\r\nuio")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})
	t:tdeq({rsoc:receive("*l")}, {"rty"})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", "uio"})

	ssoc:close()
end

---@param t testing.T
function test.receive_line_timeout(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rty")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", "rty"})

	ssoc:send("asd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive("*l")}, {"asd"})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", "fgh"})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_line_prefix(t, rsoc, ssoc)
	ssoc:send("qwe\r\nrty\r\nuio")

	t:tdeq({rsoc:receive("*l", "asd")}, {"asdqwe"})
	t:tdeq({rsoc:receive("*l", "asd")}, {"asdrty"})
	t:tdeq({rsoc:receive("*l", "asd")}, {nil, "timeout", "asduio"})
	t:tdeq({rsoc:receive("*l", "asd")}, {nil, "timeout", "asd"})
	t:tdeq({rsoc:receive("*l", "asd")}, {nil, "timeout", "asd"})

	ssoc:close()
end

---@param t testing.T
function test.receive_line_prefix_timeout(t, rsoc, ssoc)
	t:tdeq({rsoc:receive("*l", "asd")}, {nil, "timeout", "asd"})

	ssoc:close()
end

---@param t testing.T
function test.receive_all(t, rsoc, ssoc)
	ssoc:send("qwerty")
	ssoc:close()

	t:tdeq({rsoc:receive("*a")}, {"qwerty"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})

	ssoc:close()
end

---@param t testing.T
function test.receive_all_timeout(t, rsoc, ssoc)
	ssoc:send("qwe")

	t:tdeq({rsoc:receive("*a")}, {nil, "timeout", "qwe"})

	ssoc:send("rty")
	ssoc:close()

	t:tdeq({rsoc:receive("*a")}, {"rty"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
function test.receive_all_prefix(t, rsoc, ssoc)
	ssoc:send("qwe")

	t:tdeq({rsoc:receive("*a", "asd")}, {nil, "timeout", "asdqwe"})
	t:tdeq({rsoc:receive("*a", "asd")}, {nil, "timeout", "asd"})
	t:tdeq({rsoc:receive("*a", "asd")}, {nil, "timeout", "asd"})

	ssoc:send("rty")
	ssoc:close()

	t:tdeq({rsoc:receive("*a", "asd")}, {"asdrty"})
	t:tdeq({rsoc:receive("*a", "asd")}, {nil, "closed", "asd"})
	t:tdeq({rsoc:receive("*a", "asd")}, {nil, "closed", "asd"})
end

---@param t testing.T
function test.remainder_all(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rty")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})

	ssoc:send("asd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive("*a")}, {"r\rtyasd\r\nfgh"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
function test.remainder_size(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rty")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})

	t:tdeq({rsoc:receive(1)}, {"r"})
	t:tdeq({rsoc:receive(1)}, {"\r"})

	ssoc:send("asd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive(3)}, {"tya"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", "sd\13\nfgh"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

return test
