local class = require("class")

---@class web.Pages
---@operator call: web.Pages
local Pages = class()

---@param domain web.IDomain
---@param config table
---@param pages {[string]: web.Page}
---@param views web.Views
function Pages:new(domain, config, pages, views)
	self.domain = domain
	self.config = config
	self.pages = pages
	self.views = views
end

---@param page_name string
---@param ctx table
function Pages:render(page_name, ctx)
	local Page = self.pages[page_name]
	ctx.page = Page(self.domain, ctx, ctx.session_user, self.config)
	ctx.page:load()

	return self.views:render(Page.view, ctx)
end

return Pages
