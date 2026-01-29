local ffi = require("ffi")
local utf8 = require("utf8")

---@param s string
---@param c string?
local function validate(s, c)
	c = c or "?"
	local size = #s
	local buffer = ffi.new("char[?]", size)

	---@type {[integer]: integer}
	local ptr = ffi.cast("char*", buffer)
	ffi.copy(buffer, s, size)

	local len, pos = utf8.len(s)
	while not len do
		ptr[pos - 1] = c:byte()
		---@type {[integer]: integer}
		ptr = ptr + pos
		s = s:sub(pos + 1)
		len, pos = utf8.len(s)
	end

	return ffi.string(buffer, size)
end

return validate
