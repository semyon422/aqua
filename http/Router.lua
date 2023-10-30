local socket_url = require("socket.url")
local class = require("class")

local Router = class()

function Router:new(handler)
	self.handler = handler
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

function Router:handle_request(req)
	local parsed_url = socket_url.parse(req.uri)
	if not parsed_url then
		return
	end
	req.parsed_url = parsed_url
	for _, route in ipairs(self.routes) do
		if route.method == req.method then
			local matched = {parsed_url.path:match(route.pattern)}
			if #matched > 0 then
				local path_params = {}
				for i, k in ipairs(route.keys) do
					path_params[k] = matched[i]
				end
				return self.handler:handle_route(
					req,
					path_params,
					unpack(route.config, 1, route.config.n)
				)
			end
		end
	end
end

return Router
