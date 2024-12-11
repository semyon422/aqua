local class = require("class")
local Headers = require("web.http.Headers")
local BoundarySocket = require("web.socket.BoundarySocket")

-- https://www.w3.org/Protocols/rfc1341/7_2_Multipart.html

---@class web.Multipart
---@operator call: web.Multipart
local Multipart = class()

Multipart.boundary = "------------------------d67fe448c18233b3"

---@param soc web.IExtendedSocket
---@param boundary string?
function Multipart:new(soc, boundary)
	self.soc = soc
	self.boundary = boundary

	self.receive_until_boundary = soc:receiveuntil("\r\n--" .. self.boundary)
	self.bsoc = BoundarySocket(self.receive_until_boundary)
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function Multipart:receive_preamble()
	return self.receive_until_boundary()
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function Multipart:receive_epilogue()
	return self.soc:receive("*a")
end

---@return web.Headers?
---@return "closed"|"timeout"|"no parts"|"invalid boundary line ending"|"malformed headers"?
function Multipart:receive()
	local data, err, partial = self.soc:receive("*l")
	if not data then
		return nil, err
	end

	if data ~= "" and data ~= "--" then
		return nil, "invalid boundary line ending"
	end

	if data == "--" then
		return nil, "no parts"
	end

	local headers = Headers()
	local ok, err = headers:receive(self.soc)
	if not ok then
		return nil, err
	end

	self.bsoc:reset()

	return headers
end

---@param headers web.Headers?
---@return 1?
---@return "closed"|"timeout"?
function Multipart:next_part(headers)
	if not headers then
		local data, err, partial = self.soc:send(("\r\n--%s--\r\n"):format(self.boundary))
		if not data then
			return nil, err
		end
		return
	end

	local data, err, partial = self.soc:send(("\r\n--%s\r\n"):format(self.boundary))
	if not data then
		return nil, err
	end

	headers.soc = self.soc
	headers:send(self.soc)

	return 1
end

return Multipart
