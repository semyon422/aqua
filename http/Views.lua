local View = require("http.View")
local class = require("class")

---@class http.Views
---@operator call: http.Views
local Views = class()

---@param views table
---@param usecases http.Usecases
function Views:new(views, usecases)
	self._views = views
	self.usecases = usecases
end

---@param env table
---@return table
function Views:new_viewable_env(env)
	local new_env = setmetatable({}, {__index = env})
	new_env.view = View(new_env, self, self.usecases)
	return new_env
end

---@param name string
---@return function
function Views:__index(name)
	if Views[name] then
		return Views[name]
	end
	local mod = self._views[name]
	return function(result)
		return mod(Views.new_viewable_env(self, result))
	end
end

return Views
