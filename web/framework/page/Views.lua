local View = require("web.framework.page.View")
local class = require("class")

---@class web.Views
---@operator call: web.Views
---@field [string] web.View
local Views = class()

---@param templates {[string]: fun(env: table): string}
function Views:new(templates)
	self.templates = templates
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
		assert(not next(env))  -- security check, env should be an empty table
		return tpl(env)
	end
end

---@param view_config table|string
---@param result table
---@return string
function Views:render(view_config, result)
	if type(view_config) == "string" then
		return self:template(view_config)(result)
	end

	if not view_config[1] then
		local outer, inner = next(view_config)
		---@cast outer string
		---@cast inner table|string
		result.inner = self:render(inner, result)
		return self:render(outer, result)
	end

	local out = {}
	for _, vc in ipairs(view_config) do
		local s = self:render(vc, result)
		table.insert(out, s)
	end
	return table.concat(out)
end

return Views
