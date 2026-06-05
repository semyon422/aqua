local IMultipart = require("web.content.IMultipart")
local Headers = require("web.http.Headers")
local BoundarySocket = require("web.socket.BoundarySocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

-- https://www.w3.org/Protocols/rfc1341/7_2_Multipart.html

---@class web.Multipart: web.IMultipart
---@operator call: web.Multipart
local Multipart = IMultipart + {}

Multipart.boundary = "------------------------d67fe448c18233b3"

---@param soc web.IExtendedSocket
---@param boundary string?
function Multipart:new(soc, boundary)
	self.soc = soc
	self.boundary = boundary
	self.is_first_boundary = true
	self.has_preamble = false

	self.receive_until_first_boundary = soc:receiveuntil("--" .. self.boundary)
	self.receive_until_boundary = soc:receiveuntil("\r\n--" .. self.boundary)
	self.bsoc = BoundarySocket(self.receive_until_boundary)
	self.esoc = ExtendedSocket(self.bsoc)
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function Multipart:receive_preamble()
	local data, err, partial = self.receive_until_first_boundary()
	if not data then
		return nil, err, partial
	end

	if data:sub(-2) == "\r\n" then
		data = data:sub(1, -3)
	end

	return data
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function Multipart:receive_epilogue()
	return self.soc:receive("*a")
end

---@return web.Headers?
---@return "closed"|"timeout"|"no parts"|"invalid boundary line ending"|"malformed headers"?
function Multipart:receive_headers()
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
	self.esoc = ExtendedSocket(self.bsoc)

	return headers
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function Multipart:receive(pattern, prefix)
	return self.esoc:receive(pattern, prefix)
end

---@param data string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function Multipart:send_preamble(data)
	self.has_preamble = #data > 0
	return self.soc:send(data)
end

---@private
---@return string
function Multipart:get_boundary_prefix()
	return self.is_first_boundary and (self.has_preamble and "\r\n" or "") or "\r\n"
end

---@param closing boolean?
---@return 1?
---@return "closed"|"timeout"?
function Multipart:send_boundary(closing)
	local suffix = closing and "--\r\n" or "\r\n"
	local data, err, partial = self.soc:send(("%s--%s%s"):format(self:get_boundary_prefix(), self.boundary, suffix))
	if not data then
		return nil, err
	end
	self.is_first_boundary = false
	return 1
end

---@param headers web.Headers
---@return 1?
---@return "closed"|"timeout"?
function Multipart:send_headers(headers)
	assert(headers, "headers are required")

	headers.soc = self.soc
	local h, err = headers:send(self.soc)

	return h and 1 or nil, err
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function Multipart:send(data, i, j)
	return self.soc:send(data, i, j)
end

return Multipart
