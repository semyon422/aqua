local LineAllDecorator = require("web.socket.LineAllDecorator")
local StringSocket = require("web.socket.StringSocket")

local test = {}

---@param t testing.T
function test.all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc = LineAllDecorator(StringSocket())
		f(t, soc, soc)
	end
end

---@param t testing.T
function test.chunk_size_1(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc = LineAllDecorator(StringSocket())
		soc.chunk_size = 1
		f(t, soc, soc)
	end
end

return test
