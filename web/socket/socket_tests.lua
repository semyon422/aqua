local test = {}

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_0(t, rsoc, ssoc)
	ssoc:send("qw")
	ssoc:close()

	t:tdeq({rsoc:receive(0)}, {""})
	t:tdeq({rsoc:receive(0)}, {""})

	t:tdeq({rsoc:receive(1)}, {"q"})
	t:tdeq({rsoc:receive(0)}, {""})
	t:tdeq({rsoc:receive(0)}, {""})

	t:tdeq({rsoc:receive(1)}, {"w"})

	t:tdeq({rsoc:receive(0)}, {nil, "closed", ""})
	t:tdeq({rsoc:receive(0)}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_size_exact(t, rsoc, ssoc)
	ssoc:send("qwe")
	ssoc:close()

	t:tdeq({rsoc:receive(3)}, {"qwe"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_size_more(t, rsoc, ssoc)
	ssoc:send("qwe")
	ssoc:close()

	t:tdeq({rsoc:receive(4)}, {nil, "closed", "qwe"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
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
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_size_prefix(t, rsoc, ssoc)
	ssoc:send("qwerty")

	t:tdeq({rsoc:receive(2, "asd")}, {"asd"})
	t:tdeq({rsoc:receive(3, "asd")}, {"asd"})
	t:tdeq({rsoc:receive(4, "asd")}, {"asdq"})
	t:tdeq({rsoc:receive(5, "asd")}, {"asdwe"})

	ssoc:close()
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
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
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_empty_line(t, rsoc, ssoc)
	ssoc:send("\r\n\r\n")

	t:tdeq({rsoc:receive("*l")}, {""})
	t:tdeq({rsoc:receive("*l")}, {""})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", ""})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", ""})

	ssoc:send("\r\n\r\n")
	ssoc:close()

	t:tdeq({rsoc:receive("*l")}, {""})
	t:tdeq({rsoc:receive("*l")}, {""})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_line_multiple_close(t, rsoc, ssoc)
	ssoc:send("qwe\r\nrty\r\nuio")
	ssoc:close()

	t:tdeq({rsoc:receive("*l")}, {"qwe"})
	t:tdeq({rsoc:receive("*l")}, {"rty"})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", "uio"})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*l")}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_line_multiple_timeout(t, rsoc, ssoc)
	ssoc:send("qwe\r\nrty\r\nuio")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})
	t:tdeq({rsoc:receive("*l")}, {"rty"})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", "uio"})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", ""})
	t:tdeq({rsoc:receive("*l")}, {nil, "timeout", ""})

	ssoc:close()
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
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
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_line_prefix(t, rsoc, ssoc)
	ssoc:send("qwe\r\nrty\r\nuio")

	t:tdeq({rsoc:receive("*l", "as\rd")}, {"as\rdqwe"})
	t:tdeq({rsoc:receive("*l", "as\rd")}, {"as\rdrty"})
	t:tdeq({rsoc:receive("*l", "as\rd")}, {nil, "timeout", "as\rduio"})
	t:tdeq({rsoc:receive("*l", "as\rd")}, {nil, "timeout", "as\rd"})
	t:tdeq({rsoc:receive("*l", "as\rd")}, {nil, "timeout", "as\rd"})

	ssoc:close()
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_line_prefix_timeout(t, rsoc, ssoc)
	t:tdeq({rsoc:receive("*l", "asd")}, {nil, "timeout", "asd"})

	ssoc:close()
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receive_all(t, rsoc, ssoc)
	ssoc:send("qwerty")
	ssoc:close()

	t:tdeq({rsoc:receive("*a")}, {"qwerty"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})

	ssoc:close()
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
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
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
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
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.remainder_all(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rtyasd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive("*l")}, {"qwe"})
	t:tdeq({rsoc:receive("*a")}, {"r\rtyasd\r\nfgh"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.remainder_all_split(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rty")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})

	ssoc:send("asd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive("*a")}, {"r\rtyasd\r\nfgh"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.remainder_all_prefix(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rtyasd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive("*l")}, {"qwe"})
	t:tdeq({rsoc:receive("*a", "zxc")}, {"zxcr\rtyasd\r\nfgh"})
	t:tdeq({rsoc:receive("*a", "zxc")}, {nil, "closed", "zxc"})
	t:tdeq({rsoc:receive("*a", "zxc")}, {nil, "closed", "zxc"})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.remainder_size(t, rsoc, ssoc)
	ssoc:send("qw\re\r\nr\rty")

	t:tdeq({rsoc:receive("*l")}, {"qwe"})

	t:tdeq({rsoc:receive(1)}, {"r"})
	t:tdeq({rsoc:receive(1)}, {"\r"})

	ssoc:send("asd\r\nfgh")
	ssoc:close()

	t:tdeq({rsoc:receive(3)}, {"tya"})
	t:tdeq({rsoc:receive(3)}, {"sd\r"})
	t:tdeq({rsoc:receive(100)}, {nil, "closed", "\nfgh"})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.send_empty(t, rsoc, ssoc)
	t:tdeq({ssoc:send("")}, {0})
	t:tdeq({ssoc:send("")}, {0})
	t:tdeq({ssoc:send("", 3, 4)}, {2})

	ssoc:close()

	-- t:tdeq({ssoc:send("")}, {0})
	-- t:tdeq({ssoc:send("")}, {0})

	t:tdeq({rsoc:receive("*a")}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.send_oob(t, rsoc, ssoc)
	t:tdeq({ssoc:send("hello", 10, 15)}, {9})
	t:tdeq({ssoc:send("world", -15, -10)}, {0})
	t:tdeq({ssoc:send("qwert", -4, -2)}, {4})
	t:tdeq({ssoc:send("yuiop", -4, 4)}, {4})
	t:tdeq({ssoc:send("asdfg", -2, 2)}, {3}) -- nothing sent
	t:tdeq({ssoc:send("hjkl;", -10, 2)}, {2})
	t:tdeq({ssoc:send("zxcvb", 4, 10)}, {5})

	ssoc:close()

	-- t:tdeq({ssoc:send("")}, {0})
	-- t:tdeq({ssoc:send("")}, {0})

	t:tdeq({rsoc:receive("*a")}, {"weruiohjvb"})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.send_range(t, rsoc, ssoc)
	local s = "qwertyuiop"

	t:tdeq({ssoc:send(s, 1, 3)}, {3})
	t:tdeq({ssoc:send(s, 4, 5)}, {5})

	ssoc:close()

	t:tdeq({ssoc:send(s, 6, 7)}, {nil, "closed", 5})
end

return test
