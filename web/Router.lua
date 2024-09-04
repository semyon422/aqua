local class = require("class")

---@class web.Router
---@operator call: web.Router
local Router = class()

function Router:new()
	self.routes = {}
end

---@param uri string
function Router:route(method, uri, ...)
	local keys = {}
	local pattern = uri:gsub(":([^/]+)", function(key)
		table.insert(keys, key)
		return "([^/]+)"
	end)
	table.insert(self.routes, {
		pattern = "^" .. pattern .. "$",
		keys = keys,
		method = method,
		config = {n = select("#", ...), ...},
	})
end

function Router:route_many(_routes)
	for _, route in ipairs(_routes) do
		local uri = route[1]
		for method, args in pairs(route[2]) do
			self:route(method, uri, unpack(args))
		end
	end
end

function Router:handle(path, method)
	for _, route in ipairs(self.routes) do
		if route.method == method then
			local matched = {path:match(route.pattern)}
			if #matched > 0 then
				local path_params = {}
				for i, k in ipairs(route.keys) do
					path_params[k] = matched[i]
				end
				return path_params, route.config
			end
		end
	end
end

return Router
