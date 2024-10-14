local IHandler = require("web.IHandler")

---@class web.UsecaseContext: web.HandlerContext
---@field usecase_name string
---@field result_type string
---@field results string
---@field page_name string
local UsecaseContext = {}

---@class web.UsecaseHandler: web.IHandler
---@operator call: web.UsecaseHandler
local UsecaseHandler = IHandler + {}

---@param domain web.IDomain
---@param usecases {[string]: web.Usecase}
---@param config table
function UsecaseHandler:new(domain, usecases, config, default_results)
	self.domain = domain
	self.usecases = usecases
	self.config = config
	self.default_results = default_results
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.UsecaseContext
function UsecaseHandler:handle(req, res, ctx)
	local Usecase = self.usecases[ctx.usecase_name]
	local usecase = Usecase(self.domain, self.config)
	local result_type = usecase:handle(ctx)

	local code_page_headers = ctx.results[result_type] or self.default_results[result_type]
	assert(code_page_headers, tostring(result_type))

	local code, page, headers = unpack(code_page_headers, 1, 3)
	ctx.page_name = page

	res.status = code
	if type(headers) == "function" then
		headers = headers(ctx)
	end
	for k, v in pairs(headers or {}) do
		res.headers:add(k, v)
	end
end

return UsecaseHandler
