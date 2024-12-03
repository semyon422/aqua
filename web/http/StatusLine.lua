local class = require("class")
local codes = require("web.http.codes")

-- https://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html

---@class web.StatusLine
---@operator call: web.StatusLine
---@field version string
---@field status string
---@field reason string
local StatusLine = class()

StatusLine.version = "HTTP/1.1"
StatusLine.status = "200"

---@param status string|integer
---@param reason string
function StatusLine:new(status, reason)
	self.status = tostring(status)
	self.reason = reason
end

---@param soc web.IExtendedSocket
---@return web.StatusLine?
---@return "closed"|"timeout"?
function StatusLine:receive(soc)
	local data, err = soc:receive("*l")
	if not data then
		return nil, err
	end
	self.version, self.status, self.reason = data:match("^(%S+)%s+(%S+)%s+(%S+)")
	return self
end

---@param soc web.IExtendedSocket
---@return web.StatusLine?
---@return "closed"|"timeout"?
function StatusLine:send(soc)
	local reason = self.reason or codes[tonumber(self.status)] or "Not Implemented"
	local status_line = ("%s %s %s\r\n"):format(self.version, self.status, reason)
	local bytes_sent, err = soc:send(status_line)
	if not bytes_sent then
		return nil, err
	end
	return self
end

return StatusLine
