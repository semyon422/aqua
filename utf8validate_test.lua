local utf8validate = require("utf8validate")

local test = {}

---@param t testing.T
function test.preserves_valid_utf8(t)
	local value = "ASCII Привет 😀"
	t:eq(utf8validate(value), value)
end

---@param t testing.T
function test.replaces_invalid_utf8_bytes(t)
	t:eq(utf8validate("bad\255text"), "bad?text")
	t:eq(utf8validate("\192\175"), "??")
	t:eq(utf8validate("\237\160\128"), "???")
end

return test
