local IHandler = require("web.IHandler")

---@class web.UsecaseContext: web.HandlerContext
---@field result_type string
local UsecaseContext = {}

---@class web.UsecaseHandler: web.IHandler
---@operator call: web.UsecaseHandler
local UsecaseHandler = IHandler + {}

function UsecaseHandler:new(domain, usecases, config)
	self.domain = domain
	self.usecases = usecases
	self.config = config
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.RouterContext
function UsecaseHandler:handle(req, res, ctx)
	---@cast ctx +web.UsecaseContext
	local Usecase = self.usecases[ctx.usecase_name]
	local usecase = Usecase(self.domain, self.config)
	ctx.result_type = usecase:handle(ctx)
end

return UsecaseHandler
