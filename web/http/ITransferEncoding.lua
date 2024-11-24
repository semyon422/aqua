local class = require("class")

-- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding

---@class web.ITransferEncoding
---@operator call: web.ITransferEncoding
local ITransferEncoding = class()

ITransferEncoding.name = "unknown"

---@param soc web.IExtendedSocket
function ITransferEncoding:new(soc)
	self.soc = soc
end

---@return string?
---@return "closed"|"timeout"?
---@return string?
function ITransferEncoding:receive() end

---@param data string?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function ITransferEncoding:send(data) end

return ITransferEncoding
