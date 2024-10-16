local IHandler = require("web.IHandler")

---@class web.ReceiveHandler: web.IHandler
---@operator call: web.ReceiveHandler
local ReceiveHandler = IHandler + {}

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ConverterContext
function ReceiveHandler:handle(req, res, ctx)
	req:receive()
end

return ReceiveHandler
