local class = require("class")
local Route = require("web.framework.router.Route")

---@class web.Router
---@operator call: web.Router
---@field routes {[1]: web.Route, [2]: {[web.HttpMethod]: string}, [3]: web.IResource}[]
local Router = class()

function Router:new()
	self.routes = {}
end

---@param resources web.IResource[]
function Router:route(resources)
	for _, resource in ipairs(resources) do
		for _, t in ipairs(resource.routes) do
			table.insert(self.routes, {Route(t[1]), t[2], resource})
		end
	end
end

---@param path string
---@return web.IResource?
---@return {[string]: string}?
---@return {[web.HttpMethod]: string}?
function Router:getResource(path)
	for _, t in ipairs(self.routes) do
		local route, methods, resource = t[1], t[2], t[3]
		local path_params = route:match(path)
		if path_params then
			return resource, path_params, methods
		end
	end
end

return Router
