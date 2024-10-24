local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")

local test = {}

---@param t testing.T
function test.abcabd(t)
	local cp = socket_compiled_pattern_t()
	socket_compile_pattern("abcabd", cp)
	t:tdeq(cp, {recovering={nil,nil,{chr="c",new_state=3}}})
end

---@param t testing.T
function test.aaaaad(t)
	local cp = socket_compiled_pattern_t()
	socket_compile_pattern("aaaaad", cp)
	t:tdeq(cp, {recovering={nil,nil,{chr="a",new_state=5}}})
end

---@param t testing.T
function test.aacaad(t)
	local cp = socket_compiled_pattern_t()
	socket_compile_pattern("aacaad", cp)
	t:tdeq(cp, {recovering={[0]={chr="a",new_state=2},nil,nil,{chr="c",new_state=3,next={chr="a",new_state=2}}}})
end

return test
