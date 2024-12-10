local IHandler = require("web.framework.IHandler")

---@class web.SendHandler: web.IHandler
---@operator call: web.SendHandler
local SendHandler = IHandler + {}

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ConverterContext
function SendHandler:handle(req, res, ctx)
	res:send()
end

return SendHandler
