local IHandler = require("web.IHandler")

---@class web.SequentialHandler: web.IHandler
---@operator call: web.SequentialHandler
local SequentialHandler = IHandler + {}

---@param handlers web.IHandler[]
function SequentialHandler:new(handlers)
	self.handlers = handlers
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function SequentialHandler:handle(req, res, ctx)
	for _, h in ipairs(self.handlers) do
		h:handle(req, res, ctx)
	end
end

return SequentialHandler
