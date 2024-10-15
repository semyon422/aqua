local class = require("class")

---@class web.IRequest
---@operator call: web.IRequest
---@field soc web.AsyncSocket
---@field method string
---@field uri string
---@field headers web.Headers
local IRequest = class()

---@param pattern "*a"|"*l"|integer?
---@return string
function IRequest:receive(pattern)
	return ""
end

---@param body string?
function IRequest:send(body) end

return IRequest
