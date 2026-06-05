local class = require("class")

--- Common interface for multipart parsers.
---@class web.IMultipart
---@operator call: web.IMultipart
---@field bsoc web.BoundarySocket
---@field esoc web.ExtendedSocket
---@field soc web.IExtendedSocket
local IMultipart = class()

--- Read the preamble text before the first boundary.
---@return string?
---@return "closed"|"timeout"?
---@return string?
function IMultipart:receive_preamble()
	error("not implemented")
end

--- Read headers of the next part.
---@return web.Headers?
---@return "closed"|"timeout"|"no parts"|"invalid boundary line ending"|"malformed headers"?
function IMultipart:receive_headers()
	error("not implemented")
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function IMultipart:receive(pattern, prefix)
	error("not implemented")
end

--- Read the epilogue text after the closing boundary.
---@return string?
---@return "closed"|"timeout"?
---@return string?
function IMultipart:receive_epilogue()
	error("not implemented")
end

---@param data string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function IMultipart:send_preamble(data)
	error("not implemented")
end

---@param closing boolean?
---@return 1?
---@return "closed"|"timeout"?
function IMultipart:send_boundary(closing)
	error("not implemented")
end

---@param headers web.Headers
---@return 1?
---@return "closed"|"timeout"?
function IMultipart:send_headers(headers)
	error("not implemented")
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function IMultipart:send(data, i, j)
	error("not implemented")
end

return IMultipart
