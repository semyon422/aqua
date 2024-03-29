local View = require("http.View")
local class = require("class")

---@class http.Views
---@operator call: http.Views
---@field _views table
---@field [string] http.View
local Views = class()

---@param views table
function Views:new(views)
	self._views = views
end

---@param env table
---@return table
function Views:new_viewable_env(env)
	env.view = View(env, self)
	return setmetatable({}, {__index = env})
end

---@param view_config table
---@param result table
---@return string
function Views:render(view_config, result)
	if type(view_config) == "string" then
		return self[view_config](result)
	end

	if not view_config[1] then
		local outer, inner = next(view_config)
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

---@param name string
---@return function?
function Views:__index(name)
	if Views[name] then
		return Views[name]
	end
	if name:sub(1, 1) == "_" then
		return
	end
	local mod = self._views[name]
	return function(result)
		local env = Views.new_viewable_env(self, result)
		assert(not next(env))  -- security check, env should be an empty table
		return mod(env)
	end
end

return Views
