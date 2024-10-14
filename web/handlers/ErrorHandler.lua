local IHandler = require("web.IHandler")

---@class web.ErrorHandler: web.IHandler
---@operator call: web.ErrorHandler
local ErrorHandler = IHandler + {}

---@param handler web.IHandler
function ErrorHandler:new(handler)
	self.handler = handler
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function ErrorHandler:handle(req, res, ctx)
	local ok, err = xpcall(self.handler.handle, debug.traceback, self.handler, req, res, ctx)
	if ok then
		return
	end

	local body = ("<pre>%s</pre>"):format(err)

	res.status = 500
	res.headers:add("Content-Length", #body)

	res:writeStatusLine()
	res:writeHeaders()
	res:write(body)
end

return ErrorHandler
