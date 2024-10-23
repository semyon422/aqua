local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")

local test = {}

---@param t testing.T
function test.basic(t)
	local cp = socket_compiled_pattern_t()

	socket_compile_pattern("abcabd", cp)
end

return test
