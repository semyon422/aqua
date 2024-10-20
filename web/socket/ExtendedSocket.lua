local IExtendedSocket = require("web.socket.IExtendedSocket")

---@class web.ExtendedSocket: web.IExtendedSocket
---@operator call: web.ExtendedSocket
---@field remainder string
local ExtendedSocket = IExtendedSocket + {}

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
	assert(not prefix, "not implemented")

	if type(pattern) == "number" then
		return self:receiveSize(pattern)
	elseif pattern == "*l" then
		return self:receiveLine()
	elseif pattern == "*a" then
		return self:receiveAll()
	end
end

---@private
---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveSize(size)
	---@type string[]
	local buffer = {}

	local total = 0
	while true do
		local line, err, partial = self.soc:receive(1)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)
		total = total + #data

		if total == size then
			return table.concat(buffer)
		end

		if not line then
			return nil, err, table.concat(buffer)
		end
	end
end

---@private
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveLine()
	---@type string[]
	local buffer = {}

	while true do
		local line, err, partial = self.soc:receive(1)

		local data = line or partial
		---@cast data string

		if data == "\n" then
			return (table.concat(buffer):gsub("\r", ""))
		end

		table.insert(buffer, data)

		if not line then
			return nil, err, (table.concat(buffer):gsub("\r", ""))
		end
	end
end

---@private
---@return string?
---@return "closed"|"timeout"?
---@return string?
function ExtendedSocket:receiveAll()
	---@type string[]
	local buffer = {}

	while true do
		local line, err, partial = self.soc:receive(1)

		local data = line or partial
		---@cast data string

		table.insert(buffer, data)

		if err then
			local ret = table.concat(buffer)
			if err == "closed" and #ret > 0 then
				return ret
			end
			return nil, err, ret
		end
	end
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedSocket:receiveany(max)
	local line, err, partial = self.soc:receive(max)

	local data = line or partial
	---@cast data string

	if #data > 0 then
		return data
	end

	return nil, err
end

---@param s string
---@param pattern string
---@return integer?
local function find_ambiguity(s, pattern)
	for i = 2, #pattern do
		local start = #s - #pattern + i
		if s:sub(start) == pattern:sub(1, #pattern - i + 1) then
			return start
		end
	end
end

assert(find_ambiguity("qwerty", "rtyuio") == 4)
assert(not find_ambiguity("qwertyuiop", "rty"))
assert(not find_ambiguity("qwerty", "rty"))
assert(not find_ambiguity("qwerty", "qwe"))
assert(not find_ambiguity("qwerty", "qwerty"))
assert(find_ambiguity("qwe", "qwerty") == 1)

---@param s string
---@param pattern string
---@return integer?
local function reverse_find_ambiguity(s, pattern)
	for i = #pattern, 2, -1 do
		local start = #s - #pattern + i
		if s:sub(start) == pattern:sub(1, #pattern - i + 1) then
			return start
		end
	end
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function ExtendedSocket:receiveuntil(pattern, options)
	assert(#pattern > 0, "pattern is empty")
	local inclusive = options and options.inclusive

	local state = 0

	return function(size)
		if size then
			if state == -1 then
				state = 0
				return
			end

			---@type string[]
			local buffer = {}

			local ambig_offset = 0
			local ready = false

			while true do
				local line, err, partial = self.soc:receive(1)

				local data = line or partial
				---@cast data string

				if not err then
					if data == pattern:sub(ambig_offset + 1, ambig_offset + 1) then
						ambig_offset = ambig_offset + 1
						if ambig_offset == #pattern then
							data = pattern
							ready = true
							ambig_offset = 0
						elseif not line then
							data = pattern:sub(1, ambig_offset)
						else
							goto continue
						end
					elseif ambig_offset > 0 then
						if ambig_offset < #pattern then
							data = pattern:sub(1, ambig_offset) .. data
						end
						ambig_offset = 0
						if data:sub(#data) == pattern:sub(1, 1) then
							ambig_offset = 1
							data = data:sub(1, #data - 1)
						end
					end
				end

				if ready then
					state = -1
					if inclusive then
						table.insert(buffer, data)
					end
					return table.concat(buffer)
				end

				table.insert(buffer, data)
				local ret = table.concat(buffer)

				if size <= #ret then
					if ambig_offset == 0 then
						return ret:sub(1, size)
					end
				end

				if not line then
					return nil, err, table.concat(buffer)
				end

				::continue::
			end

			return
		end

		---@type string[]
		local buffer = {}

		local ambig_offset = 0
		local ready = false

		while true do
			local line, err, partial = self.soc:receive(1)

			local data = line or partial
			---@cast data string

			if data == pattern:sub(ambig_offset + 1, ambig_offset + 1) then
				ambig_offset = ambig_offset + 1
				if ambig_offset == #pattern then
					data = pattern
					ready = true
					ambig_offset = 0
				elseif not line then
					data = pattern:sub(1, ambig_offset)
				else
					goto continue
				end
			elseif ambig_offset > 0 then

				local ambig_start = reverse_find_ambiguity(pattern:sub(2, ambig_offset), pattern)
				if not ambig_start then
					data = pattern:sub(1, ambig_offset) .. data

					ambig_start = ambig_start or 1
					ambig_offset = ambig_start - 1
					if data:sub(#data) == pattern:sub(ambig_start, ambig_start) then
						data = data:sub(1, #data - 1)
						ambig_offset = ambig_start
					end
				else

					ambig_start = ambig_start + 1
					if data == pattern:sub(ambig_start, ambig_start) then
						data = pattern:sub(1, 1)
					else
						if data == pattern:sub(ambig_start - 1, ambig_start - 1) then
							data = pattern:sub(1, ambig_start - 1)
							ambig_offset = ambig_start - 1
						else
							data = pattern:sub(1, ambig_start) .. data
							ambig_offset = 0
						end
					end
				end
			end

			if ready then
				if inclusive then
					table.insert(buffer, data)
				end
				return table.concat(buffer)
			end

			table.insert(buffer, data)
			local ret = table.concat(buffer)

			if not line then
				return nil, err, ret
			end

			::continue::
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
	return self.soc:send(data:sub(i or 1, j))
end

---@return 1
function ExtendedSocket:close()
	return self.soc:close()
end

return ExtendedSocket
