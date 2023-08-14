local function return_from_new(t, ...)
	if select("#", ...) > 0 then
		return ...
	end
	return t
end

local function new(T, ...)
	if not T.new then
		return setmetatable(... or {}, T)
	end
	local t = setmetatable({}, T)
	return return_from_new(t, t:new(...))
end

local function isclass(T)
	if type(T) ~= "table" then
		return false
	end

	local mt = getmetatable(T)
	return mt and mt.__call == new
end

local function typeof(T, t)
	if type(t) ~= "table" then
		return false
	end

	local _T = t
	if not isclass(t) then
		_T = getmetatable(t)
	end
	if _T == T then
		return true
	end

	while _T do
		local p = getmetatable(_T).__index
		if p == T then
			return true
		end
		_T = p
	end

	return false
end

local function class(p, t)
	if p then
		assert(isclass(p), "bad argument #1 to 'class'")
	end

	local mt = {
		__index = p,
		__call = new,
		__add = class,
		__mul = typeof,
	}

	local T = t or {}
	T.__index = T

	return setmetatable(T, mt)
end

-- tests

local A = class()
local B = A + {}

local b = B()

assert(B * b)
assert(A * b)

assert(B * B)
assert(A * B)

return class
