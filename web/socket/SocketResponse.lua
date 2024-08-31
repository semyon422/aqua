local http_codes = require("http.codes")
local async_client = require("http.async_client")
local IResponse = require("web.IResponse")

---@class web.SocketResponse: web.IResponse
---@operator call: web.SocketResponse
local SocketResponse = IResponse + {}

---@param soc TCPSocket
function SocketResponse:new(soc)
	self.soc = soc
	self.status = 200
	self.headers = {}
	self.headers_sent = false
	---@type string[]
	self.buffer = {}
end

---@param content_length integer
function SocketResponse:writeHeaders(content_length)
	local status = self.status
	local headers = self.headers
	local buffer = self.buffer

	headers["Content-Length"] = content_length

	table.insert(buffer, ("HTTP/1.1 %s %s"):format(status, http_codes[status]))

	for k, v in pairs(headers) do
		table.insert(buffer, ("%s: %s"):format(k, v))
	end
	table.insert(buffer, "")

	self.headers_sent = true
end

---@param data string?
function SocketResponse:write(data)
	local buffer = self.buffer
	self:writeHeaders(#data)
	table.insert(buffer, data)
	return async_client.send(self.soc, table.concat(buffer, "\r\n"))
end

return SocketResponse
