local class = require("class")

local type_to_pattern = {
	[":"] = "([^/]+)",
	["+"] = "(.+)",
	["*"] = "(.*)",
}

---@class web.Route
---@operator call: web.Route
local Route = class()

---@param pattern string
function Route:new(pattern)
	---@type string[]
	local keys = {}

	-- First parse route parameters (:key, +key, *key)
	-- Key is alphanumeric + underscore, ends at non-alphanumeric
	pattern = pattern:gsub("([%:%+%*])([%w_]+)", function(_type, key)
		table.insert(keys, key)
		return type_to_pattern[_type]
	end)

	-- Then escape remaining Lua pattern special characters
	-- Note: ( ) [ ] * + ? ^ $ | are NOT escaped because they're part of the pattern groups
	-- We only escape . % - which are common in URLs but special in Lua patterns
	pattern = pattern:gsub("([%.%-])", "%%%1")

	self.pattern = "^" .. pattern .. "$"
	self.keys = keys
end

---@param path string
---@return {[string]: string}?
function Route:match(path)
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
