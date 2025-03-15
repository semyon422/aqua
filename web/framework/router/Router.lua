local class = require("class")
local Route = require("web.framework.router.Route")

---@class web.Router
---@operator call: web.Router
---@field routes {[1]: web.Route, [2]: web.IResource}[]
local Router = class()

function Router:new()
	self.routes = {}
end

---@param resources web.IResource[]
function Router:route(resources)
	for _, resource in ipairs(resources) do
		table.insert(self.routes, {Route(resource.uri), resource})
	end
end

---@param path string
---@return web.IResource?
---@return {[string]: string}?
function Router:getResource(path)
	for _, route_resource in ipairs(self.routes) do
		local route, resource = route_resource[1], route_resource[2]
		local path_params = route:match(path)
		if path_params then
			return resource, path_params
		end
	end
end

return Router
