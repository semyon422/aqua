local class = require("class")

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

---@param last true?
function MultipartFormData:send_boundary(last)
	self.soc:send(("--%s%s\r\n"):format(self.boundary, last and "--" or ""))
end

return MultipartFormData
