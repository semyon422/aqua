local IHandler = require("web.IHandler")

---@class web.SendHandler: web.IHandler
---@operator call: web.SendHandler
local SendHandler = IHandler + {}

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ConverterContext
function SendHandler:handle(req, res, ctx)
	res:sendStatusLine()
	res:sendHeaders()
end

return SendHandler
