local codes = require("web.socket.codes")
local IResponse = require("web.IResponse")

---@class web.SocketResponse: web.IResponse
---@operator call: web.SocketResponse
local SocketResponse = IResponse + {}

---@param soc web.AsyncSocket
function SocketResponse:new(soc)
	self.soc = soc
	self.status = 200
	---@type {[string]: any}
	self.headers = {}
	self.headers_set = false
end

---@param content_length integer
function SocketResponse:setHeaders(content_length)
	if self.headers_set then
		return
	end

	local status = self.status
	local headers = self.headers

	---@type string[]
	local buffer = {}

	if not headers["Content-Length"] then
		headers["Content-Length"] = content_length
	end

	table.insert(buffer, ("HTTP/1.1 %s %s"):format(status, codes[status]))

	for k, v in pairs(headers) do
		table.insert(buffer, ("%s: %s"):format(k, v))
	end
	table.insert(buffer, "")
	table.insert(buffer, "")

	self.soc:write(table.concat(buffer, "\r\n"))

	self.headers_set = true
end

---@param data string?
function SocketResponse:write(data)
	self:setHeaders(#data)
	if not data then
		return
	end
	self.soc:write(data)
end

return SocketResponse
