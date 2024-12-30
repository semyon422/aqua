local ISocket = require("web.socket.ISocket")

---@class web.LengthSocket: web.ISocket
---@operator call: web.LengthSocket
local LengthSocket = ISocket + {}

---@param err string?
---@return "timeout"|"closed early"
local function closed_early_or_timeout(err)
	return err == "timeout" and "timeout" or "closed early"
end

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
---@return "closed"|"timeout"|"closed early"?
---@return string?
function LengthSocket:receive(size)
	if self.length == 0 then
		return nil, "closed", ""
	end

	local data, err, partial = self.soc:receive(math.min(size, self.length))
	self.length = self.length - #(data or partial)

	if not data then
		return nil, closed_early_or_timeout(err), partial
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
	assert(not i and not j, "not implemented")

	local length = self.length
	if length == 0 then
		return nil, "closed", 0
	end

	if length >= #data then
		local bytes, err, _bytes = self.soc:send(data)
		self.length = length - (bytes or _bytes)
		return bytes, err, _bytes
	end

	local bytes, err, _bytes = self.soc:send(data:sub(1, length))
	self.length = length - (bytes or _bytes)

	if not bytes then
		return bytes, err, _bytes
	end

	return nil, "closed", bytes
end

return LengthSocket
