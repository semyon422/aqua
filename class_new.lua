local extend = {}
local base = {}

local function return_from_new(t, ...)
	if select("#", ...) > 0 then
		return ...
	end
	return t
end

---@param f function|string? Parent constructor
---@param get_base boolean? Return class table, constructor, metatable
---@return table T Class table
---@return fun(...: any):table new Class constructor
---@return table mt Class metatable
return function(f, get_base)
	if type(f) == "string" then
		f = require(f)
	end

	if f and get_base then
		return f(base)
	end

	local T = type(f) == "function" and f(extend) or {}
	local mt = {__index = T}

	local function new(...)
		if ... == base then
			return T, new, mt
		end
		local t = setmetatable({}, mt)
		if rawget(T, "new") and ... ~= extend then
			return return_from_new(t, t:new(...))
		end
		return t
	end

	return T, new, mt
end
