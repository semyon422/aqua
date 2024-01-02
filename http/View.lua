local class = require("class")

---@class http.View
---@operator call: http.View
local View = class()

---@param env table
---@param views http.Views
---@param usecases http.Usecases
function View:new(env, views, usecases)
	self.env = env
	self.views = views
	self.usecases = usecases
end

---@param name string
---@return string
function View:render(name)
	return self.views[name](self.env)
end

---@param usecase_name string
---@return boolean
function View:authorize(usecase_name)
	local usecase = self.usecases[usecase_name]
	return usecase:authorize(self.env) == "permit"
end

---@param env table
---@return http.View
function View:__call(env)
	setmetatable(env, {__index = self.env})
	return self.views:new_viewable_env(env).view
end

return View
