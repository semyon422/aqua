local socket_compile_pattern = require("web.nginx.socket_compile_pattern")
local socket_compiled_pattern_t = require("web.nginx.socket_compiled_pattern_t")
local ngx_str_t = require("web.nginx.ngx_str_t")

local test = {}

---@param t testing.T
function test.qwerty(t)
	local cp = socket_compiled_pattern_t()
	local pat = ngx_str_t("qwerty")
	socket_compile_pattern(pat.data, pat.len, cp)
	t:eq(cp.recovering, nil)
end

---@param t testing.T
function test.abcabd(t)
	local cp = socket_compiled_pattern_t()
	local pat = ngx_str_t("abcabd")
	socket_compile_pattern(pat.data, pat.len, cp)
	t:tdeq(cp.recovering, {nil,nil,{chr=99,new_state=3}})
end

---@param t testing.T
function test.aaaaad(t)
	local cp = socket_compiled_pattern_t()
	local pat = ngx_str_t("aaaaad")
	socket_compile_pattern(pat.data, pat.len, cp)
	t:tdeq(cp.recovering, {nil,nil,{chr=97,new_state=5}})
end

---@param t testing.T
function test.aacaad(t)
	local cp = socket_compiled_pattern_t()
	local pat = ngx_str_t("aacaad")
	socket_compile_pattern(pat.data, pat.len, cp)
	t:tdeq(cp.recovering, {[0]={chr=97,new_state=2},nil,nil,{chr=99,new_state=3,next={chr=97,new_state=2}}})
end

return test
