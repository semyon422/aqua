---@param f function? Parent constructor
---@param ... any Parent constructor arguments
---@return table T Class table
---@return fun(...: any): table new Class constructor
---@return table mt Class metatable
return function(f, ...)
	local T = f and f() or {}
	local mt = {__index = T}
	return T, function(...)
		local t = setmetatable({}, mt)
		if T.new then t:new(...) end
		return t
	end, mt
end
