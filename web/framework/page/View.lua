local class = require("class")

---@class web.View
---@operator call: web.View
local View = class()

---@param env table
---@param views web.Views
function View:new(env, views)
	self.env = env
	self.views = views
end

---@param name string
---@return string
function View:render(name)
	return self.views:template(name)(self.env)
end

---@param env table
---@return web.View
function View:__call(env)
	setmetatable(env, {__index = self.env})
	return self.views:new_viewable_env(env).view
end

return View
