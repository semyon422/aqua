local class = require("class")

local type_to_pattern = {
	[":"] = "([^/]+)",
	["+"] = "(.+)",
	["*"] = "(.*)",
}

---@class web.Route
---@operator call: web.Route
local Route = class()

---@param method string
---@param pattern string
---@param ctx table
function Route:new(method, pattern, ctx)
	local keys = {}
	pattern = pattern:gsub("([%:%+%*])([^/]+)", function(_type, key)
		table.insert(keys, key)
		return type_to_pattern[_type]
	end)
	self.pattern = "^" .. pattern .. "$"
	self.keys = keys
	self.method = method
	self.ctx = ctx
end

---@param method string
---@param path string
---@return {[string]: string}?
function Route:match(method, path)
	if method ~= self.method then
		return
	end

	---@type string[]
	local values = {path:match(self.pattern)}
	if #values == 0 then
		return
	end

	---@type {[string]: string}
	local path_params = {}
	for i, k in ipairs(self.keys) do
		path_params[k] = values[i]
	end

	return path_params
end

return Route
