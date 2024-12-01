local class = require("class")
local Headers = require("web.http.Headers")
local BoundarySocket = require("web.socket.BoundarySocket")

---@class web.MultipartFormData
---@operator call: web.MultipartFormData
local MultipartFormData = class()

MultipartFormData.boundary = "------------------------d67fe448c18233b3"

---@param soc web.IExtendedSocket
---@param boundary string?
function MultipartFormData:new(soc, boundary)
	self.soc = soc
	self.boundary = boundary

	self.receive_until_boundary = soc:receiveuntil("\r\n--" .. self.boundary)
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function MultipartFormData:receive_preamble()
	return self.receive_until_boundary()
end

---@return web.Headers?
---@return web.ISocket|"closed"|"timeout"|"invalid boundary line ending"|"malformed headers"?
function MultipartFormData:receive()
	local data, err, partial = self.soc:receive("*l")
	if not data then
		return nil, err
	end

	if data ~= "" and data ~= "--" then
		return nil, "invalid boundary line ending"
	end

	if data == "--" then
		return nil, "closed"
	end

	local headers = Headers(self.soc)
	local ok, err = headers:receive()
	if not ok then
		return nil, err
	end

	local soc = BoundarySocket(self.receive_until_boundary)

	return headers, soc
end

---@param last true?
function MultipartFormData:send_boundary(last)
	self.soc:send(("--%s%s\r\n"):format(self.boundary, last and "--" or ""))
end

return MultipartFormData
