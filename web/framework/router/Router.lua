local class = require("class")
local Route = require("web.framework.router.Route")

---@class web.Router
---@operator call: web.Router
---@field routes {[1]: web.Route, [2]: any}[]
local Router = class()

function Router:new()
	self.routes = {}
end

---@param pattern string
---@param resource any
function Router:route(pattern, resource)
	table.insert(self.routes, {Route(pattern), resource})
end

---@param path string
---@return {[string]: string}?
---@return any?
function Router:getResource(path)
	for _, route_resource in ipairs(self.routes) do
		local route, resource = unpack(route_resource)
		local path_params = route:match(path)
		if path_params then
			return resource, path_params
		end
	end
end

return Router
