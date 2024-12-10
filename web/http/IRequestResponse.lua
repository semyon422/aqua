local ISocket = require("web.socket.ISocket")

---@class web.IRequestResponse: web.ISocket
---@operator call: web.IRequestResponse
---@field headers web.Headers
local IRequestResponse = ISocket + {}

---@private
---@return true?
---@return "closed"|"timeout"|"malformed headers"?
function IRequestResponse:receive_headers()
	error("not implemented")
end

---@private
---@return true?
---@return "closed"|"timeout"?
function IRequestResponse:send_headers()
	error("not implemented")
end

---@param data string
---@return 1?
---@return "closed"|"timeout"?
function IRequestResponse:print(data)
	error("not implemented")
end

---@param wait boolean?
---@return 1?
---@return "closed"|"timeout"?
function IRequestResponse:flush(wait)
	error("not implemented")
end

---@return 1?
---@return "closed"|"timeout"?
function IRequestResponse:eof()
	error("not implemented")
end

return IRequestResponse
