local class = require("class")
local Route = require("web.framework.router.Route")

---@class web.Router
---@operator call: web.Router
---@field routes {[1]: web.Route, [2]: {[web.HttpMethod]: string}, [3]: web.IResource, [4]: string[]?}[]
local Router = class()

function Router:new()
	self.routes = {}
end

---@param resources web.IResource[]
function Router:route(resources)
	for _, resource in ipairs(resources) do
		for _, t in ipairs(resource.routes) do
			table.insert(self.routes, {Route(t[1]), t[2], resource, resource.domains})
		end
	end
end

--- Match a domain against a list of patterns. Patterns support "*" as a wildcard for any suffix.
--- E.g. "c.*" matches "c.example.com" and "c.other.net".
---@param host string
---@param patterns string[]
---@return boolean
function Router:domain_match(host, patterns)
	for _, pattern in ipairs(patterns) do
		if pattern == host then
			return true
		end
		if pattern:find("%*") then
			-- Convert glob-style pattern to Lua pattern: * matches any suffix
			-- Dots are kept as-is (Lua . matches any char, which covers literal dots)
			local lua_pattern = "^" .. pattern:gsub("%*", ".*") .. "$"
			if host:match(lua_pattern) then
				return true
			end
		end
	end
	return false
end

---@param path string
---@param host string?
---@return web.IResource?
---@return {[string]: string}?
---@return {[web.HttpMethod]: string}?
function Router:getResource(path, host)
	-- Build matching passes: domain-restricted first, then unrestricted
	local passes = {}
	if host then
		table.insert(passes, function(domains) return domains and #domains > 0 and self:domain_match(host, domains) end)
	end
	table.insert(passes, function(domains) return not domains or #domains == 0 end)

	for _, predicate in ipairs(passes) do
		for _, t in ipairs(self.routes) do
			local route, methods, resource, domains = t[1], t[2], t[3], t[4]
			if predicate(domains) then
				local path_params = route:match(path)
				if path_params then
					return resource, path_params, methods
				end
			end
		end
	end
end

return Router
