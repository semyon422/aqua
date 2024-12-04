local ISocket = require("web.socket.ISocket")

---@class web.LengthSocket: web.ISocket
---@operator call: web.LengthSocket
local LengthSocket = ISocket + {}

---@param soc web.ISocket
---@param length integer
function LengthSocket:new(soc, length)
	self.soc = soc
	self.length = length
end

---@return 1
function LengthSocket:close()
	self.length = 0
	return 1
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function LengthSocket:receive(size)
	if self.length == 0 then
		return nil, "closed", ""
	end

	local data, err, partial = self.soc:receive(math.min(size, self.length))
	self.length = self.length - #(data or partial)

	if not data then
		return nil, err, partial
	end

	if self.length == 0 and size > #data then
		return nil, "closed", data
	end

	return data
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function LengthSocket:send(data, i, j)
	i = i or 1
	j = j or #data

	if self.length == 0 then
		return nil, "closed", i - 1
	end

	local data_size = j - i + 1
	local avail_size = self.length
	if avail_size >= data_size then
		local bytes, err, _bytes = self.soc:send(data, i, j)
		self.length = avail_size - (bytes or _bytes) + i - 1
		return bytes, err, _bytes
	end

	local last_byte = i + avail_size - 1

	local bytes, err, _bytes = self.soc:send(data, i, last_byte)
	self.length = avail_size - (bytes or _bytes) + i - 1

	if not bytes then
		return bytes, err, _bytes
	end

	return nil, "closed", bytes
end

return LengthSocket
