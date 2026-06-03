local class = require("class")

--- Common interface for multipart parsers.
---@class web.IMultipart
---@operator call: web.IMultipart
---@field bsoc web.BoundarySocket
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
function IMultipart:receive()
	error("not implemented")
end

--- Read the epilogue text after the closing boundary.
---@return string?
---@return "closed"|"timeout"?
---@return string?
function IMultipart:receive_epilogue()
	error("not implemented")
end

return IMultipart
