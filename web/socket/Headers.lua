local class = require("class")

---@class web.Headers
---@operator call: web.Headers
---@field headers {[string]: string|string[]}
local Headers = class()

function Headers:new()
	self.headers = {}
end

---@param name string
---@param value string
function Headers:add(name, value)
	local headers = self.headers
	-- name = name:lower()

	local header = headers[name]
	if type(header) == "table" then
		table.insert(header, value)
	elseif type(header) == "string" then
		headers[name] = {header, value}
	else
		headers[name] = value
	end
end

---@param next_line fun(): string?, string?
---@return true?
---@return string?
function Headers:decode(next_line)
	local line, err = next_line()
	if not line then
		return nil, err
	end

	while line ~= "" do
		local name, value = line:match("^(.-):%s*(.*)")
		if not name then
			return nil, "malformed headers"
		end

		-- folded values
		line, err = next_line()
		if not line then
			return nil, err
		end

		while line:find("^%s") do
			value = value .. line
			line, err = next_line()
			if not line then
				return nil, err
			end
		end

		self:add(name, value)
	end

	return true
end

---@return string
function Headers:encode()
	local out = "\r\n"

	for k, v in pairs(self.headers) do
		out = ("%s: %s\r\n%s"):format(k, v, out)
	end

	return out
end

return Headers
