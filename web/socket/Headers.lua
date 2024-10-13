local IHeaders = require("web.socket.IHeaders")

---@class web.Headers: web.IHeaders
---@operator call: web.Headers
---@field headers {[string]: string|string[]}
local Headers = IHeaders + {}

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

---@param soc web.IAsyncSocket
---@return true?
---@return "closed"|"malformed headers"?
---@return string?
function Headers:receive(soc)
	local line, err, partial = soc:receive("*l")
	if not line then
		return nil, err, partial
	end

	while line ~= "" do
		local name, value = line:match("^(.-):%s*(.*)")
		if not name then
			return nil, "malformed headers"
		end
		---@cast name string
		---@cast value string

		-- folded values
		line, err, partial = soc:receive("*l")
		if not line then
			return nil, err, partial
		end

		while line:find("^%s") do
			value = value .. line
			line, err, partial = soc:receive("*l")
			if not line then
				return nil, err, partial
			end
		end

		self:add(name, value)
	end

	return true
end

---@return string[]
function Headers:getKeys()
	---@type string[]
	local keys = {}
	for k in pairs(self.headers) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

---@param soc web.IAsyncSocket
---@return integer?
---@return "closed"?
---@return integer?
function Headers:send(soc)
	---@type string[]
	local out = {}
	for _, k in ipairs(self:getKeys()) do
		table.insert(out, ("%s: %s\r\n"):format(k, self.headers[k]))
	end

	table.insert(out, "\r\n")
	return soc:send(table.concat(out))

	-- for _, header in ipairs(self.headers) do
	-- 	self.soc:send(("%s: %s\r\n"):format(header[1], header[2]))
	-- end
	-- self.soc:send("\r\n")
end

return Headers
