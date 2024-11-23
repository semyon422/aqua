local IFilter = require("web.filter.IFilter")

---@class web.SocketFilter: web.ISocket
---@operator call: web.SocketFilter
local SocketFilter = IFilter + {}

---@param soc web.ISocket
function SocketFilter:new(soc)
	self.soc = soc
end

---@param size integer
---@return string?
---@return string?
function SocketFilter:receive(size)
	local data, err, partial = self.soc:receive(size)
	data = data or partial
	if #data > 0 then
		return data
	end
	if err == "timeout" then
		return ""
	end
	return nil, err
end

---@param data string
---@return integer?
---@return string?
function SocketFilter:send(data)
	local last_byte, err, _last_byte = self.soc:send(data)
	last_byte = last_byte or _last_byte
	if last_byte > 0 then
		return last_byte
	end
	if err == "timeout" then
		return 0
	end
	return nil, err
end

function SocketFilter:close()
	self.soc:close()
end

return SocketFilter
