local IRequest = require("web.IRequest")

---@class web.SocketRequest: web.IRequest
---@operator call: web.SocketRequest
local SocketRequest = IRequest + {}

---@param soc web.Socket
function SocketRequest:new(soc)
	self.soc = soc
	---@type {[string]: string}
	self.headers = {}
end

function SocketRequest:readHeaders()
	while true do
		local line, err = self.soc:read("*l")  -- closed
		if not line then
			return nil, err
		end

		if not self.method then
			self.method, self.uri, self.protocol = line:match("^(%S+)%s+(%S+)%s+(%S+)")
		else
			local key, value = line:match("^(%S+):%s+(.+)")
			if key then
				self.headers[key] = value
			end
		end
		if line == "" then
			break
		end
	end
	self.length = tonumber(self.headers["Content-Length"]) or 0
	return true
end

---@param size integer?
---@return string
function SocketRequest:read(size)
	local length = tonumber(self.headers["Content-Length"]) or 0
	if length == 0 then
		return ""
	end
	return self.soc:read(size)
end

return SocketRequest
