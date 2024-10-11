local ISocket = require("web.socket.ISocket")

---@class web.LineAllDecorator: web.ISocket
---@operator call: web.LineAllDecorator
---@field remainder string
local LineAllDecorator = ISocket + {}

LineAllDecorator.chunk_size = 4096

---@param soc web.ISocket
function LineAllDecorator:new(soc)
	self.soc = soc
	self.remainder = ""
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receive(pattern, prefix)
	assert(pattern == "*a" or pattern == "*l" or type(pattern) == "number", "invalid pattern")

	prefix = prefix or ""
	---@type string[]
	local buffer = {}
	table.insert(buffer, self.remainder)

	local rem = self.remainder
	self.remainder = ""

	if self.closed then
		if pattern == "*l" then
			rem = rem:gsub("\r", "")
		end
		return nil, "closed", (prefix or "") .. rem
	end

	if type(pattern) == "number" then
		if prefix and pattern <= #prefix then
			return prefix
		end
		return self:receiveSize(buffer, pattern, prefix)
	elseif pattern == "*l" then
		return self:receiveLine(buffer, prefix)
	elseif pattern == "*a" then
		return self:receiveAll(buffer, prefix)
	end
end

---@param buffer string[]
---@param size integer
---@param prefix string
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receiveSize(buffer, size, prefix)
	local s = table.concat(buffer)

	---@type string?
	local ret
	if size <= #s - #prefix then
		ret, self.remainder = s:sub(1, size), s:sub(size + 1)
		return prefix .. ret
	end

	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)

		if not line then
			s = table.concat(buffer)
			ret, self.remainder = s:sub(1, size - #prefix), s:sub(size - #prefix + 1)
			if err == "closed" then
				self.closed = true
			end
			if #ret == size - #prefix then
				return prefix .. ret
			end
			return nil, err, prefix .. ret
		end
	end
end

---@param buffer string[]
---@param prefix string
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receiveLine(buffer, prefix)
	local s = table.concat(buffer)

	---@type string?, string?
	local _line, remainder = s:match("^(.-)\n(.*)$")
	if _line then
		self.remainder = remainder
		table.insert(buffer, _line)
		return prefix .. _line:gsub("\r", "")
	end

	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		local data = line or partial
		---@cast data string

		---@type string?, string?
		local _line, remainder = data:match("^(.-)\n(.*)$")
		if _line then
			self.remainder = remainder
			table.insert(buffer, _line)
			if err == "closed" then
				self.closed = true
			end
			return prefix .. table.concat(buffer):gsub("\r", "")
		end

		table.insert(buffer, data)

		if not line then
			return nil, err, prefix .. table.concat(buffer):gsub("\r", "")
		end
	end
end

---@param buffer string[]
---@param prefix string
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LineAllDecorator:receiveAll(buffer, prefix)
	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)

		if err == "closed" then
			self.closed = true
			return prefix .. table.concat(buffer)
		elseif err == "timeout" then
			return nil, err, prefix .. table.concat(buffer)
		end
	end
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function LineAllDecorator:send(data, i, j)
	return self.soc:send(data, i, j)
end

---@return 1
function LineAllDecorator:close()
	return self.soc:close()
end

return LineAllDecorator
