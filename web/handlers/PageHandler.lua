local IHandler = require("web.IHandler")

---@class web.PageContext: web.HandlerContext
---@field page http.Page
local PageContext = {}

---@class web.PageHandler: web.IHandler
---@operator call: web.PageHandler
local PageHandler = IHandler + {}

function PageHandler:new(domain, config, pages, views)
	self.domain = domain
	self.config = config
	self.pages = pages
	self.views = views
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ParamsContext|web.RouterContext|web.UserContext
function PageHandler:handle(req, res, ctx)
	---@cast ctx +web.PageContext

	local page = ctx.page_name
	if not page then
		res:write()
		return
	end

	local Page = self.pages[page]
	ctx.page = Page(self.domain, ctx, ctx.session_user, self.config)
	ctx.page:load()
	local body = self.views:render(Page.view, ctx)

	res:write(body)
end

return PageHandler
