local class = require("class")

---@class web.MultipartParser
---@operator call: web.MultipartParser
local MultipartParser = class()

---@param headers {[string]: string}
function MultipartParser:new(headers)
	self.headers = headers
end

local function parse_part(s)
	local part = {
		headers = {},
	}

	local headers_string, body = s:match("^(.-\r\n)\r\n(.*)$")
	part.body = body

	for header in headers_string:gmatch("([^\r^\n]*)\r\n") do
		local k, v = header:match("^(.-): (.+)$")
		part.headers[k] = v
	end

	return part
end

---@param body string
---@return table
function MultipartParser:read(body)
	local content_type, boundary = self.headers["Content-Type"]:match("^(.+); boundary=(.-)$")
	assert(content_type == "multipart/form-data")

	local parts = {}

	local i = 1
	while i <= #body - #boundary - 6 do
		local a, b = body:find("--" .. boundary, i, true)
		local c, d = body:find("--" .. boundary, b + 1, true)
		table.insert(parts, parse_part(body:sub(b + 3, c - 3)))
		i = c
	end

	return parts
end

return MultipartParser
