local test = {}

-- some tests was taken from lua-nginx-module
-- https://github.com/openresty/lua-nginx-module/blob/master/t/066-socket-receiveuntil.t

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_timeout(t, rsoc, ssoc)
	ssoc:send("qwe||rty||asd")

	local read = rsoc:receiveuntil("||")

	t:tdeq({read()}, {"qwe"})
	t:tdeq({read()}, {"rty"})
	t:tdeq({read()}, {nil, "timeout", "asd"})
	t:tdeq({read()}, {nil, "timeout", ""})
	t:tdeq({read()}, {nil, "timeout", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_closed(t, rsoc, ssoc)
	ssoc:send("qwe||rty||asd")
	ssoc:close()

	local read = rsoc:receiveuntil("||")

	t:tdeq({read()}, {"qwe"})
	t:tdeq({read()}, {"rty"})
	t:tdeq({read()}, {nil, "closed", "asd"})
	t:tdeq({read()}, {nil, "closed", ""})
	t:tdeq({read()}, {nil, "closed", ""})
end

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_ambiguous_closed(t, rsoc, ssoc)
	ssoc:send("qweqwerty")
	ssoc:close()

	local read = rsoc:receiveuntil("qwerty")

	t:tdeq({read()}, {"qwe"})
	t:tdeq({read()}, {nil, "closed", ""})
	t:tdeq({read()}, {nil, "closed", ""})
end

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_size_timeout(t, rsoc, ssoc)
-- 	ssoc:send("qwertyasdfgh")

-- 	local read = rsoc:receiveuntil("asd")

-- 	t:tdeq({read(4)}, {"qwer"})
-- 	t:tdeq({read(4)}, {"ty"})
-- 	t:tdeq({read(4)}, {})
-- 	t:tdeq({read(4)}, {nil, "timeout", "fgh"})
-- 	t:tdeq({read(4)}, {nil, "timeout", ""})
-- 	t:tdeq({read(4)}, {nil, "timeout", ""})
-- end

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_size_full_incomplete(t, rsoc, ssoc)
-- 	ssoc:send("qwerty")

-- 	local reader = rsoc:receiveuntil("zxc")

-- 	t:tdeq({reader(2)}, {"qw"})
-- 	t:tdeq({reader(2)}, {"er"})
-- 	t:tdeq({reader(2)}, {"ty"})
-- 	t:tdeq({reader(2)}, {nil, "timeout", ""})

-- 	ssoc:close()
-- end

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_size_ambiguous_incomplete(t, rsoc, ssoc)
-- 	ssoc:send("qwerty")

-- 	local reader = rsoc:receiveuntil("rtyuio")

-- 	t:tdeq({reader(2)}, {"qw"})
-- 	t:tdeq({reader(2)}, {nil, "timeout", "e"})

-- 	ssoc:close()
-- end

-- === TEST 4: ambiguous boundary patterns (abcabd)

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_test_4(t, rsoc, ssoc)
	ssoc:send("abcabcabd\n")
	ssoc:close()

	local reader = rsoc:receiveuntil("abcabd")

	t:tdeq({reader()}, {"abc"})
	t:tdeq({reader()}, {nil, "closed", "\n"})
	t:tdeq({reader()}, {nil, "closed", ""})
end

-- === TEST 5: ambiguous boundary patterns (aa)

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_test_5(t, rsoc, ssoc)
	ssoc:send("abcabcaad\n")
	ssoc:close()

	local reader = rsoc:receiveuntil("aa")

	t:tdeq({reader()}, {"abcabc"})
	t:tdeq({reader()}, {nil, "closed", "d\n"})
	t:tdeq({reader()}, {nil, "closed", ""})
end

-- === TEST 7: ambiguous boundary patterns (aaaaad)

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_test_7(t, rsoc, ssoc)
	ssoc:send("baaaaaaaaeaaaaaaadf\n")
	ssoc:close()

	local reader = rsoc:receiveuntil("aaaaad")

	t:tdeq({reader()}, {"baaaaaaaaeaa"})
	t:tdeq({reader()}, {nil, "closed", "f\n"})
	t:tdeq({reader()}, {nil, "closed", ""})
end

-- === TEST 17: ambiguous boundary patterns (--abc), small buffer, mixed by other reading calls

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_test_17(t, rsoc, ssoc)
-- 	ssoc:send("hello, world ----abc\n")
-- 	ssoc:close()

-- 	local reader = rsoc:receiveuntil("--abc")

-- 	t:tdeq({reader(4)}, {"hell"})
-- 	t:tdeq({rsoc:receive(1)}, {"o"})
-- 	t:tdeq({reader(4)}, {", wo"})
-- 	t:tdeq({rsoc:receive(1)}, {"r"})
-- 	t:tdeq({reader(4)}, {"ld -"})
-- 	t:tdeq({rsoc:receive(1)}, {"-"})
-- 	t:tdeq({reader(4)}, {""})
-- 	t:tdeq({rsoc:receive(1)}, {"\n"})
-- 	t:tdeq({reader(4)}, {})
-- 	t:tdeq({rsoc:receive(1)}, {nil, "closed", ""})
-- end

-- === TEST 21: ambiguous boundary patterns (--abc), mixed by other reading calls consume boundary

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_test_21(t, rsoc, ssoc)
-- 	ssoc:send("----abc----abc-\n")
-- 	ssoc:close()

-- 	local reader = rsoc:receiveuntil("--abc")

-- 	t:tdeq({reader(2)}, {"--"})
-- 	t:tdeq({rsoc:receive(1)}, {"-"})
-- 	t:tdeq({reader(2)}, {"-a"})
-- 	t:tdeq({rsoc:receive(1)}, {"b"})
-- 	t:tdeq({reader(2)}, {"c-"})
-- 	t:tdeq({rsoc:receive(1)}, {"-"})
-- 	t:tdeq({reader(2)}, {""})
-- 	t:tdeq({rsoc:receive(1)}, {"-"})
-- 	t:tdeq({reader(2)}, {})
-- 	t:tdeq({reader(2)}, {nil, "closed", "\n"})
-- 	t:tdeq({reader(2)}, {nil, "closed", ""})
-- end

-- === TEST 22: ambiguous boundary patterns (--abc), mixed by other reading calls (including receiveuntil) consume boundary

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_test_22(t, rsoc, ssoc)
-- 	ssoc:send("------abd----abc\n")
-- 	ssoc:close()

-- 	local reader1 = rsoc:receiveuntil("--abc")
-- 	local reader2 = rsoc:receiveuntil("-ab")

-- 	t:tdeq({reader1(2)}, {"--"})
-- 	t:tdeq({rsoc:receive(1)}, {"-"})
-- 	t:tdeq({reader1(1)}, {"-"})
-- 	t:tdeq({reader2(2)}, {"-"})
-- 	t:tdeq({reader1()}, {"d--"})
-- 	t:tdeq({reader1()}, {nil, "closed", "\n"})
-- 	t:tdeq({reader1()}, {nil, "closed", ""})
-- end

-- === TEST 25: ambiguous boundary patterns (ab1ab2), ends half way

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_test_25(t, rsoc, ssoc)
-- 	ssoc:send("ab1ab1\n")

-- 	local reader = rsoc:receiveuntil("ab1ab2")

-- 	t:tdeq({reader(2)}, {"ab1"})
-- 	t:tdeq({rsoc:receive(3)}, {"ab2"})

-- 	ssoc:close()
-- end

-- === TEST 1: ambiguous boundary patterns (abcabd) - inclusive mode

---@param t testing.T
---@param rsoc web.IExtendedSocket
---@param ssoc web.IExtendedSocket
function test.receiveuntil_inclusive_test_1(t, rsoc, ssoc)
	ssoc:send("abcabcabdabcabd\n")
	ssoc:close()

	local reader = rsoc:receiveuntil("abcabd", {inclusive = true})

	t:tdeq({reader()}, {"abcabcabd"})
	t:tdeq({reader()}, {"abcabd"})
	t:tdeq({reader()}, {nil, "closed", "\n"})
	t:tdeq({reader()}, {nil, "closed", ""})
end

-- === TEST 9: ambiguous boundary patterns (--abc), small buffer

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_inclusive_test_9(t, rsoc, ssoc)
-- 	ssoc:send("hello, world ----abc\n")
-- 	ssoc:close()

-- 	local reader = rsoc:receiveuntil("--abc", {inclusive = true})

-- 	t:tdeq({reader(4)}, {"hell"})
-- 	t:tdeq({reader(4)}, {"o, w"})
-- 	t:tdeq({reader(4)}, {"orld"})
-- 	t:tdeq({reader(4)}, {" ----abc"})
-- 	t:tdeq({reader(4)}, {})
-- 	t:tdeq({reader(4)}, {nil, "closed", "\n"})
-- 	t:tdeq({reader(4)}, {nil, "closed", ""})
-- end

-- === TEST 10: ambiguous boundary patterns (--abc), small buffer, mixed by other reading calls

-- ---@param t testing.T
-- ---@param rsoc web.IExtendedSocket
-- ---@param ssoc web.IExtendedSocket
-- function test.receiveuntil_inclusive_test_10(t, rsoc, ssoc)
-- 	ssoc:send("hello, world ----abc\n")
-- 	ssoc:close()

-- 	local reader = rsoc:receiveuntil("--abc", {inclusive = true})

-- 	t:tdeq({reader(4)}, {"hell"})
-- 	t:tdeq({rsoc:receive(1)}, {"o"})
-- 	t:tdeq({reader(4)}, {", wo"})
-- 	t:tdeq({rsoc:receive(1)}, {"r"})
-- 	t:tdeq({reader(4)}, {"ld -"})
-- 	t:tdeq({rsoc:receive(1)}, {"-"})
-- 	t:tdeq({reader(4)}, {"--abc"})
-- 	t:tdeq({rsoc:receive(1)}, {"\n"})
-- 	t:tdeq({reader(4)}, {})
-- 	t:tdeq({rsoc:receive(4)}, {nil, "closed", ""})
-- end

return test
