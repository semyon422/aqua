local function new(T, ...)
	return setmetatable(... or {}, T)
end

return function(p)
	local T = {}
	T.__index = T
	return setmetatable(T, {
		__index = p,
		__call = new,
	})
end
