local class = require("class")
local async_client = require("http.async_client")

---@class web.Socket
---@operator call: web.Socket
local Socket = class()

---@param soc TCPSocket
function Socket:new(soc)
	self.soc = soc
end

---@param pattern any
---@return string
function Socket:read(pattern)
	return async_client.receive(self.soc, pattern)
end

---@param data string
function Socket:write(data)
	async_client.send(self.soc, data)
end

return Socket
