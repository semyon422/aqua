local extend = {}

---@param f function? Parent constructor
---@return table T Class table
---@return fun(...: any): table new Class constructor
---@return table mt Class metatable
return function(f)
	local T = f and f(extend) or {}
	local mt = {__index = T}
	return T, function(...)
		local t = setmetatable({}, mt)
		if T.new and ... ~= extend then t:new(...) end
		return t
	end, mt
end
