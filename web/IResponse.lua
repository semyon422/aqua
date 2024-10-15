local class = require("class")

---@class web.IResponse
---@operator call: web.IResponse
---@field soc web.AsyncSocket
---@field status integer
---@field headers web.Headers
local IResponse = class()

function IResponse:receiveStatusLine() end
function IResponse:sendStatusLine() end

function IResponse:receiveHeaders() end
function IResponse:sendHeaders() end

---@param pattern "*a"|"*l"|integer?
---@return string
function IResponse:receive(pattern)
	return ""
end

---@param body string?
function IResponse:send(body) end

return IResponse
