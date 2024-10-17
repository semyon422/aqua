local IExtendedSocket = require("web.socket.IExtendedSocket")

---@class web.ExtendedSocket: web.IExtendedSocket
---@operator call: web.ExtendedSocket
---@field remainder string
local ExtendedSocket = IExtendedSocket + {}

ExtendedSocket.chunk_size = 4096

---@param soc web.ISocket
function ExtendedSocket:new(soc)
	self.soc = soc
	self.remainder = ""
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receive(pattern, prefix)
	assert(pattern == "*a" or pattern == "*l" or type(pattern) == "number", "invalid pattern")

	prefix = prefix or ""

	if type(pattern) == "number" then
		return self:receiveSize(pattern, prefix)
	elseif pattern == "*l" then
		return self:receiveLine(prefix)
	elseif pattern == "*a" then
		return self:receiveAll(prefix)
	end
end

---@private
---@param size integer
---@param prefix string
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveSize(size, prefix)
	local rem = self.remainder

	size = size - #prefix
	if prefix and size <= 0 then
		return prefix
	end

	if size <= #rem then
		self.remainder = rem:sub(size + 1)
		return prefix .. rem:sub(1, size)
	end

	if self.closed then
		self.remainder = ""
		return nil, "closed", prefix .. rem
	end

	---@type string[]
	local buffer = {rem}
	self.remainder = ""

	local total = 0
	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)
		total = total + #data

		if err == "closed" then
			self.closed = true
		end

		if not line or total >= size then
			rem = table.concat(buffer)
			local ret = rem:sub(1, size)
			self.remainder = rem:sub(size + 1)
			if #ret == size then
				return prefix .. ret
			end
			return nil, err, prefix .. ret
		end
	end
end

---@private
---@param prefix string
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveLine(prefix)
	local rem = self.remainder

	---@type string?, string?
	local _ret, _rem = rem:match("^(.-)\n(.*)$")
	if _ret and _rem then
		self.remainder = _rem
		return prefix .. _ret:gsub("\r", "")
	end

	if self.closed then
		self.remainder = ""
		return nil, "closed", prefix .. rem:gsub("\r", "")
	end

	---@type string[]
	local buffer = {rem}
	self.remainder = ""

	while true do
		local line, err, partial = self.soc:receive(self.chunk_size)

		if err == "closed" then
			self.closed = true
		end

		local data = line or partial
		---@cast data string

		---@type string?, string?
		_ret, _rem = data:match("^(.-)\n(.*)$")
		if _ret and _rem then
			self.remainder = _rem
			table.insert(buffer, _ret)
			return prefix .. table.concat(buffer):gsub("\r", "")
		end

		table.insert(buffer, data)

		if not line then
			return nil, err, prefix .. table.concat(buffer):gsub("\r", "")
		end
	end
end

---@private
---@param prefix string
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveAll(prefix)
	local rem = self.remainder

	if self.closed then
		self.remainder = ""
		if rem ~= "" then
			return prefix .. rem
		end
		return nil, "closed", prefix .. rem
	end

	---@type string[]
	local buffer = {rem}
	self.remainder = ""

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

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedSocket:receiveany(max)
	local rem = self.remainder

	if max <= #rem then
		self.remainder = rem:sub(max + 1)
		return rem:sub(1, max)
	end

	if self.closed then
		self.remainder = ""
		if rem ~= "" then
			return rem
		end
		return nil, "closed"
	end

	---@type string[]
	local buffer = {rem}
	self.remainder = ""

	local line, err, partial = self.soc:receive(self.chunk_size)

	local data = line or partial
	---@cast data string

	table.insert(buffer, data)

	if err == "closed" then
		self.closed = true
	end

	rem = table.concat(buffer)
	local ret = rem:sub(1, max)
	self.remainder = rem:sub(max + 1)

	if #ret > 0 then
		return ret
	end

	return nil, err
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	assert(#pattern > 0, "pattern is empty")

	local state = 0

	return function(size)
		local rem = self.remainder

		if size then
			if state == -1 then
				state = 0
				return
			end

			local i, j = rem:find(pattern, 1, true)
			if i then
				state = -1
				self.remainder = rem:sub(j + 1)
				return rem:sub(1, i - 1)
			end

			---@type string[]
			local buffer = {rem}
			self.remainder = ""

			while true do
				local line, err, partial = self.soc:receive(self.chunk_size)

				if err == "closed" then
					self.closed = true
				end

				local data = line or partial
				---@cast data string

				table.insert(buffer, data)

				local ret = table.concat(buffer)

				i, j = ret:find(pattern, 1, true)

				if i and j then
					if i <= size then
						self.remainder = ret:sub(j + 1)
						return ret:sub(1, i - 1)
					end
					self.remainder = ret:sub(size + 1)
					return ret:sub(1, size)
				end

				if not line then
					return nil, err, table.concat(buffer)
				end
			end

			return
		end

		local i, j = rem:find(pattern, 1, true)
		if i then
			self.remainder = rem:sub(j + 1)
			return rem:sub(1, i - 1)
		end

		---@type string[]
		local buffer = {rem}
		self.remainder = ""

		while true do
			local line, err, partial = self.soc:receive(self.chunk_size)

			if err == "closed" then
				self.closed = true
			end

			local data = line or partial
			---@cast data string

			table.insert(buffer, data)

			local ret = table.concat(buffer)

			i, j = ret:find(pattern, 1, true)

			if i and j then
				self.remainder = ret:sub(j + 1)
				return ret:sub(1, i - 1)
			end

			if not line then
				return nil, err, table.concat(buffer)
			end
		end
	end
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ExtendedSocket:send(data, i, j)
	return self.soc:send(data, i, j)
end

---@return 1
function ExtendedSocket:close()
	return self.soc:close()
end

return ExtendedSocket
