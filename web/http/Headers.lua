local class = require("class")
local receive_line = require("web.http.receive_line")

---@class web.HttpHeaderLimits
---@field max_header_line_size integer?
---@field max_header_size integer?
---@field max_header_count integer?

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

---@param src web.Headers
---@return web.Headers
function Headers:copy(src)
	local headers = self.headers
	local header_names = self.header_names

	for lower_name, name in pairs(src.header_names) do
		header_names[lower_name] = name
	end

	for lower_name, src_values in pairs(src.headers) do
		headers[lower_name] = headers[lower_name] or {}
		local values = headers[lower_name]
		for _, value in ipairs(src_values) do
			table.insert(values, value)
		end
	end

	return self
end

---@param name string
---@param value string|number
---@return web.Headers
function Headers:add(name, value)
	local headers = self.headers
	local lower_name = name:lower()

	self.header_names[lower_name] = name

	headers[lower_name] = headers[lower_name] or {}
	table.insert(headers[lower_name], tostring(value))

	return self
end

---@param name string
---@param value any|string[]
---@return web.Headers
function Headers:set(name, value)
	local headers = self.headers
	local lower_name = name:lower()

	self.header_names[lower_name] = name

	if type(value) == "table" then
		headers[lower_name] = value
	else
		headers[lower_name] = {tostring(value)}
	end

	return self
end

---@param name string
---@return web.Headers
function Headers:unset(name)
	local lower_name = name:lower()

	self.header_names[lower_name] = nil
	self.headers[lower_name] = nil

	return self
end

---@param name string
---@return string ...
function Headers:get(name)
	local header = self.headers[name:lower()]
	if header then
		return unpack(header)
	end
end

---@param name string
---@return string[]
function Headers:getTable(name)
	return self.headers[name:lower()] or {}
end

---@param soc web.IExtendedSocket
---@param limits web.HttpHeaderLimits?
---@return web.Headers?
---@return "closed"|"timeout"|"malformed headers"|"line too long"|"headers too large"|"too many headers"?
function Headers:receive(soc, limits)
	limits = limits or {}
	local total_size = 0
	local count = 0

	---@return string?
	---@return string?
	local function next_line()
		local line, err = receive_line(soc, limits.max_header_line_size)
		if not line then
			return nil, err
		end
		total_size = total_size + #line + 2
		if limits.max_header_size and total_size > limits.max_header_size then
			return nil, "headers too large"
		end
		return line
	end

	local line, err = next_line()
	if not line then
		return nil, err
	end

	while line ~= "" do
		count = count + 1
		if limits.max_header_count and count > limits.max_header_count then
			return nil, "too many headers"
		end
		local name, value = line:match("^([^:]+):%s*(.*)")
		if not name or not name:match("^[%w!#$%%&'*+%.%^_`|~%-]+$") then
			return nil, "malformed headers"
		end
		---@cast name string
		---@cast value string

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

	return self
end

---@return string[]
function Headers:getKeys()
	---@type string[]
	local keys = {}
	for k, v in pairs(self.headers) do
		if v[1] then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	return keys
end

---@param soc web.IExtendedSocket
---@return web.Headers?
---@return "closed"|"timeout"?
function Headers:send(soc)
	local headers = self.headers
	local header_names = self.header_names

	for _, k in ipairs(self:getKeys()) do
		for _, v in ipairs(headers[k]) do
			local last_byte, err, _last_byte = soc:send(("%s: %s\r\n"):format(header_names[k], v))
			if not last_byte then
				return nil, err
			end
		end
	end

	local last_byte, err, _last_byte = soc:send("\r\n")
	if not last_byte then
		return nil, err
	end

	return self
end

return Headers
