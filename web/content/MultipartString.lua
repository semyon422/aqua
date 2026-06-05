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

---@param body string
---@param boundary string?
function MultipartString:new(body, boundary)
	self.str_soc = StringSocket(body)
	self.str_soc:close()
	local soc = ExtendedSocket(self.str_soc)
	return Multipart(soc, boundary)
end

return MultipartString
