local RequestReader = require("web.socket.RequestReader")

local test = {}

local request = [[
POST / HTTP/1.1
Content-Length: 5
Content-Type: text/plain

hello]]

request = request:gsub("\n", "\r\n")

---@param t testing.T
---@param parts string[]
local function test_parts(t, parts)
	local reader = RequestReader()

	local body_parts = {}
	for _, part in ipairs(parts) do
		local body_part = reader:read(part)
		table.insert(body_parts, body_part)
	end

	-- t:eq(reader.headers["Content-Length"], 5)
	-- t:eq(reader.headers["Content-Type"], "text/plain")
	-- t:eq(table.concat(body_parts), "hello")
end

---@param t testing.T
function test.single_char(t)
	---@type string[]
	local parts = {}
	for i = 1, #request do
		parts[i] = request:sub(i, i)
	end
	test_parts(t, parts)
end

function test.line_breaks(t)
	test_parts(t, {
		"POST / HTTP/1.1",
		"\r\n",
		"Content-Length: 5\r",
		"\nContent-Type: text/plain\r",
		"\n\r",
		"\nhello"
	})
end

return test
