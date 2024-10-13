local IHeaders = require("web.socket.IHeaders")

---@class web.Headers: web.IHeaders
---@operator call: web.Headers
---@field headers {[string]: string[]}
---@field header_names {[string]: string}
local Headers = IHeaders + {}

function Headers:new()
	self.headers = {}
	self.header_names = {}
end

---@param name string
---@param value string
function Headers:add(name, value)
	local headers = self.headers
	local lower_name = name:lower()

	self.header_names[lower_name] = name

	headers[lower_name] = headers[lower_name] or {}
	table.insert(headers[lower_name], value)
end

---@param name string
---@return string ...
function Headers:get(name)
	local header = self.headers[name:lower()]
	if header then
		return unpack(header)
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
	local headers = self.headers
	local header_names = self.header_names

	local total = 0

	for _, k in ipairs(self:getKeys()) do
		for _, v in ipairs(headers[k]) do
			local last_byte, err, _last_byte = soc:send(("%s: %s\r\n"):format(header_names[k], v))
			if not last_byte then
				return nil, err, total + _last_byte
			end
			total = total + last_byte
		end
	end

	local last_byte, err, _last_byte = soc:send("\r\n")
	if not last_byte then
		return nil, err, total + _last_byte
	end

	return total
end

return Headers
