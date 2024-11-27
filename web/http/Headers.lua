local class = require("class")

---@class web.Headers
---@operator call: web.Headers
---@field headers {[string]: string[]}
---@field header_names {[string]: string}
local Headers = class()

---@param soc web.IExtendedSocket
function Headers:new(soc)
	self.soc = soc
	self.headers = {}
	self.header_names = {}
end

---@param name string
---@param value string|number
function Headers:add(name, value)
	local headers = self.headers
	local lower_name = name:lower()

	self.header_names[lower_name] = name

	headers[lower_name] = headers[lower_name] or {}
	table.insert(headers[lower_name], tostring(value))
end

---@param name string
---@param value string|string[]
function Headers:set(name, value)
	local headers = self.headers
	local lower_name = name:lower()

	self.header_names[lower_name] = name

	if type(value) == "string" then
		headers[lower_name] = {value}
	elseif type(value) == "table" then
		headers[lower_name] = value
	end
end

---@param name string
---@return string ...
function Headers:get(name)
	local header = self.headers[name:lower()]
	if header then
		return unpack(header)
	end
end

---@return true?
---@return "closed"|"timeout"|"malformed headers"?
function Headers:receive()
	local line, err, partial = self.soc:receive("*l")
	if not line then
		return nil, err
	end

	while line ~= "" do
		local name, value = line:match("^(.-):%s*(.*)")
		if not name then
			return nil, "malformed headers"
		end
		---@cast name string
		---@cast value string

		-- folded values
		line, err, partial = self.soc:receive("*l")
		if not line then
			return nil, err
		end

		while line:find("^%s") do
			value = value .. line
			line, err, partial = self.soc:receive("*l")
			if not line then
				return nil, err
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

---@return true?
---@return "closed"|"timeout"?
function Headers:send()
	local headers = self.headers
	local header_names = self.header_names

	for _, k in ipairs(self:getKeys()) do
		for _, v in ipairs(headers[k]) do
			local last_byte, err, _last_byte = self.soc:send(("%s: %s\r\n"):format(header_names[k], v))
			if not last_byte then
				return nil, err
			end
		end
	end

	local last_byte, err, _last_byte = self.soc:send("\r\n")
	if not last_byte then
		return nil, err
	end

	return true
end

return Headers
