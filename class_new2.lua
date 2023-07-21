local function return_from_new(t, ...)
	if select("#", ...) > 0 then
		return ...
	end
	return t
end

local function new(self, ...)
	local t = setmetatable({}, self)
	if self.new then
		return return_from_new(t, t:new(...))
	end
	return t
end

local function class(p, t)
	if p then
		local mt = getmetatable(p)
		assert(mt and mt.__call == new, "bad argument #1 to 'class'")
	end

	local mt = {
		__call = new,
		__add = class,
		__index = p,
	}

	local T = t or {}
	T.__index = T

	return setmetatable(T, mt)
end

return class
