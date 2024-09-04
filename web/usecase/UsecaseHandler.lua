local IHandler = require("web.IHandler")

---@class web.UsecaseContext: web.HandlerContext
---@field usecase_name string
---@field result_type string
local UsecaseContext = {}

---@class web.UsecaseHandler: web.IHandler
---@operator call: web.UsecaseHandler
local UsecaseHandler = IHandler + {}

---@param domain web.IDomain
---@param usecases {[string]: web.Usecase}
---@param config table
function UsecaseHandler:new(domain, usecases, config)
	self.domain = domain
	self.usecases = usecases
	self.config = config
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.UsecaseContext
function UsecaseHandler:handle(req, res, ctx)
	local Usecase = self.usecases[ctx.usecase_name]
	local usecase = Usecase(self.domain, self.config)
	ctx.result_type = usecase:handle(ctx)
end

return UsecaseHandler
