local class = require("class")
local Route = require("web.framework.router.Route")

---@class web.Router
---@operator call: web.Router
---@field routes web.Route[]
local Router = class()

function Router:new()
	self.routes = {}
end

---@param method string
---@param pattern string
---@param ctx table
function Router:route(method, pattern, ctx)
	table.insert(self.routes, Route(method, pattern, ctx))
end

---@param routes {[1]: string, [2]: {[string]: table}}[]
function Router:routeMany(routes)
	for _, route in ipairs(routes) do
		local pattern = route[1]
		for method, ctx in pairs(route[2]) do
			self:route(method, pattern, ctx)
		end
	end
end

---@param path string
---@param method string
---@return {[string]: string}?
---@return table?
function Router:handle(path, method)
	for _, route in ipairs(self.routes) do
		local path_params = route:match(method, path)
		if path_params then
			return path_params, route.ctx
		end
	end
end

return Router
