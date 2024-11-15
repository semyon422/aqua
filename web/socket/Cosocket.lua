local ISocket = require("web.socket.ISocket")
local buffer = require("string.buffer")

---@class web.Cosocket: web.ISocket
---@operator call: web.Cosocket
local Cosocket = ISocket + {}

---@param soc web.ISocket
function Cosocket:new(soc)
	self.soc = soc
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function Cosocket:receive(size)
	local buf = buffer.new(size)

	while true do
		local line, err, partial = self.soc:receive(size)

		local data = line or partial
		---@cast data string
		buf:put(data)

		if err == "closed" then
			return nil, "closed", buf:tostring()
		end

		size = size - #data

		if line then
			return buf:tostring()
		elseif err == "timeout" and coroutine.yield("read") then
			return nil, "timeout", data
		end
	end
end

---@param data string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function Cosocket:send(data)
	local i, j = 1, #data

	while true do
		local last_byte, err, _last_byte = self.soc:send(data, i, j)
		if err == "closed" then
			return nil, "closed", _last_byte
		end

		local byte = last_byte or _last_byte
		---@cast byte integer

		i = byte + 1
		if last_byte then
			return last_byte
		elseif err == "timeout" and coroutine.yield("write") then
			return nil, "timeout", byte
		end
	end
end

---@return 1
function Cosocket:close()
	return self.soc:close()
end

return Cosocket
