local IMultipart = require("web.content.IMultipart")
local Multipart = require("web.content.Multipart")
local StringSocket = require("web.socket.StringSocket")
local ExtendedSocket = require("web.socket.ExtendedSocket")

--- In-memory multipart parser.
--- Parses a complete multipart body string and exposes the same interface as web.Multipart.
---@class web.MultipartString: web.IMultipart
---@operator call: web.MultipartString
---@field str_soc web.StringSocket
local MultipartString = IMultipart + {}

MultipartString.boundary = "------------------------d67fe448c18233b3"

---@param body string
---@param boundary string?
function MultipartString:new(body, boundary)
	self.str_soc = StringSocket(body)
	self.str_soc:close()
	local soc = ExtendedSocket(self.str_soc)
	local multipart = Multipart(soc, boundary)

	self.multipart = multipart
	self.bsoc = multipart.bsoc
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function MultipartString:receive_preamble()
	return self.multipart:receive_preamble()
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function MultipartString:receive_epilogue()
	return self.multipart:receive_epilogue()
end

---@return web.Headers?
---@return "closed"|"timeout"|"no parts"|"invalid boundary line ending"|"malformed headers"?
function MultipartString:receive()
	return self.multipart:receive()
end

return MultipartString
