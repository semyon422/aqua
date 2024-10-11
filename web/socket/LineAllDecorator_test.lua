local LineAllDecorator = require("web.socket.LineAllDecorator")
local FakeStringSocket = require("web.socket.FakeStringSocket")

local test = {}

---@param t testing.T
function test.all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc = LineAllDecorator(FakeStringSocket())
		f(t, soc, soc)
	end
end

return test
