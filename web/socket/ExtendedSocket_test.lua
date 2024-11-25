local ExtendedSocket = require("web.socket.ExtendedSocket")
local StringSocket = require("web.socket.StringSocket")
local PrefixSocket = require("web.socket.PrefixSocket")

local test = {}

---@param t testing.T
function test.socket_all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local ext_soc = ExtendedSocket(StringSocket())
		local soc = PrefixSocket(ext_soc)
		f(t, soc, soc)
	end

	for k, f in pairs(tpl) do
		t.name = k
		local ext_soc = ExtendedSocket(StringSocket())
		ext_soc = ExtendedSocket(ext_soc)
		local soc = PrefixSocket(ext_soc)
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.socket_small_buffer_size(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for buffer_size = 1, 16 do
		for k, f in pairs(tpl) do
			t.name = k
			local ext_soc = ExtendedSocket(StringSocket())
			local soc = PrefixSocket(ext_soc)
			ext_soc.upstream.buffer_size = buffer_size
			f(t, soc, soc)
		end
	end

	for buffer_size = 1, 16 do
		for k, f in pairs(tpl) do
			t.name = k
			local ext_soc = ExtendedSocket(StringSocket())
			ext_soc = ExtendedSocket(ext_soc)
			local soc = PrefixSocket(ext_soc)
			ext_soc.upstream.buffer_size = buffer_size
			f(t, soc, soc)
		end
	end
end

---@param t testing.T
function test.receiveuntil_all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.receiveuntil_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		f(t, soc, soc)
	end

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		soc = ExtendedSocket(soc)
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.receiveuntil_small_buffer_size(t)
	---@type {[string]: function}
	local tpl = require("web.socket.receiveuntil_tests")

	for buffer_size = 1, 16 do
		for k, f in pairs(tpl) do
			t.name = k
			local soc = ExtendedSocket(StringSocket())
			soc.upstream.buffer_size = buffer_size
			f(t, soc, soc)
		end
	end

	for buffer_size = 1, 16 do
		for k, f in pairs(tpl) do
			t.name = k
			local soc = ExtendedSocket(StringSocket())
			soc = ExtendedSocket(soc)
			soc.upstream.buffer_size = buffer_size
			f(t, soc, soc)
		end
	end
end

---@param t testing.T
function test.cosocket(t)
	---@type {[string]: function}
	local tpl = require("web.socket.cosocket_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		soc.cosocket = true
		f(t, soc, soc)
	end

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		soc = ExtendedSocket(soc)
		soc.cosocket = true
		f(t, soc, soc)
	end

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		soc.cosocket = true
		soc = ExtendedSocket(soc)
		f(t, soc, soc)
	end
end

-- receiveany will return smaller strings on smaller buffers

---@param t testing.T
function test.receiveany_all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.receiveany_tests")

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		f(t, soc, soc)
	end

	for k, f in pairs(tpl) do
		t.name = k
		local soc = ExtendedSocket(StringSocket())
		soc = ExtendedSocket(soc)
		f(t, soc, soc)
	end
end

return test
