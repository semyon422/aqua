local IAsyncSocket = require("web.socket.IAsyncSocket")

---@class web.AsyncSocket: web.IAsyncSocket
---@operator call: web.AsyncSocket
local AsyncSocket = IAsyncSocket + {}

---@param soc web.ISocket
function AsyncSocket:new(soc)
	self.soc = soc
end

---@param pattern "*a"|"*l"|integer
---@return string?
---@return "closed"?
---@return string?
function AsyncSocket:receive(pattern)
	local buffer = {}

	while true do
		local line, err, partial = self.soc:receive(pattern)

		local data = line or partial
		---@cast data string
		table.insert(buffer, data)

		if err == "closed" then
			return nil, "closed", table.concat(buffer)
		end

		if type(pattern) == "number" then
			pattern = pattern - #data
		end

		if line then
			return table.concat(buffer)
		elseif err == "timeout" then
			coroutine.yield("read")
		end
	end
end

---@param data string
---@return integer?
---@return "closed"?
---@return integer?
function AsyncSocket:send(data)
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
		elseif err == "timeout" then
			coroutine.yield("write")
		end
	end
end

---@return 1
function AsyncSocket:close()
	return self.soc:close()
end

return AsyncSocket
