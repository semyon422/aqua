local View = require("web.framework.page.View")
local class = require("class")

---@class web.Views
---@operator call: web.Views
---@field [string] web.View
local Views = class()

---@param templates {[string]: fun(env: table): string}
---@param layout string?
function Views:new(templates, layout)
	self.templates = templates
	self.layout = layout
end

---@param env table
---@return table
function Views:new_viewable_env(env)
	env.view = View(env, self)
	return setmetatable({}, {__index = env})
end

---@param path string
---@return fun(table): string
function Views:template(path)
	local tpl = self.templates[path]

	return function(result)
		local env = Views.new_viewable_env(self, result)
		assert(not next(env)) -- security check, env should be an empty table
		return tpl(env)
	end
end

---@param view_config table|string
---@param ctx table
---@param add_layout boolean?
---@return string
function Views:render(view_config, ctx, add_layout)
	if add_layout and self.layout then
		view_config = {[self.layout] = view_config}
	end

	if type(view_config) == "string" then
		return self:template(view_config)(ctx)
	end

	if not view_config[1] then
		local outer, inner = next(view_config)
		---@cast outer string
		---@cast inner table|string
		ctx.inner = self:render(inner, ctx)
		return self:render(outer, ctx)
	end

	local out = {}
	for _, vc in ipairs(view_config) do
		local s = self:render(vc, ctx)
		table.insert(out, s)
	end
	return table.concat(out)
end

---@param res web.IResponse
---@param view_config table|string
---@param ctx table
---@param add_layout boolean?
function Views:render_send(res, view_config, ctx, add_layout)
	local s = self:render(view_config, ctx, add_layout)
	res.headers:set("Content-Type", "text/html")
	res:set_length(#s)
	res:send(s)
end

return Views
