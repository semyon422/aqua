local ISocket = require("web.socket.ISocket")

---@class web.IRequestResponse: web.ISocket
---@operator call: web.IRequestResponse
---@field soc web.ISocket
---@field headers web.Headers
local IRequestResponse = ISocket + {}

---@return 1?
---@return "closed"|"timeout"|"malformed headers"?
function IRequestResponse:receive_headers()
	error("not implemented")
end

---@return 1?
---@return "closed"|"timeout"?
function IRequestResponse:send_headers()
	error("not implemented")
end

---@param length integer
function IRequestResponse:set_length(length)
	error("not implemented")
end

function IRequestResponse:set_chunked_encoding()
	error("not implemented")
end

---@param mode "r"|"w"|"rw"
function IRequestResponse:assert_mode(mode)
	error("not implemented")
end

return IRequestResponse
