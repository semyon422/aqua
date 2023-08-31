local function return_from_new(t, ...)
	if select("#", ...) > 0 then
		return ...
	end
	return t
end

local function return_from_new_xpcall(t, ok, ...)
	if ok then
		return return_from_new(t, ...)
	end
	error(..., 2)
end

local function new(T, ...)
	if not T.new then
		return setmetatable(... or {}, T)
	end
	local t = setmetatable({}, T)
	return return_from_new_xpcall(t, xpcall(T.new, debug.traceback, t, ...))
end

local function isclass(T)
	if type(T) ~= "table" then
		return false
	end

	local mt = getmetatable(T)
	return mt and mt.__call == new
end

local function typeofclass(T, _T)
	if _T == T then
		return true
	end
	if not _T then
		return false
	end

	local mt = getmetatable(_T)
	if not mt then
		return false
	end

	if mt.__indexes then
		local p, t = unpack(mt.__indexes)
		return typeofclass(T, p) or typeofclass(T, t)
	end

	return typeofclass(T, mt.__index)
end

local function typeof(T, t)
	if type(t) ~= "table" then
		return false
	end

	if not isclass(t) then
		t = getmetatable(t)
	end

	return typeofclass(T, t)
end

local function class(p, t)
	if p then
		assert(isclass(p), "bad argument #1 to 'class'")
	end

	local mt = {
		__call = new,
		__add = class,
		__mul = typeof,
	}

	local T = {}
	T.__index = T

	if not isclass(t) then
		mt.__index = p
		return setmetatable(T, mt)
	end

	mt.__indexes = {p, t}
	function mt.__index(_, k)
		local a, b = p[k], t[k]
		if a ~= nil then
			return a
		end
		return b
	end

	return setmetatable(T, mt)
end

-- tests

do
	local A = class()
	local B = A + {}

	local a = A()
	local b = B()

	assert(A * A)
	assert(A * B)
	assert(A * a)
	assert(A * b)

	assert(not (B * A))
	assert(B * B)
	assert(not (B * a))
	assert(B * b)
end

do
	local A = class()
	local B = class()
	local C = class()
	local X = A + B + C

	local x = X()

	assert(A * X)
	assert(B * X)
	assert(C * X)
	assert(X * x)

	assert(not (X * A))
	assert(not (X * B))
	assert(not (X * C))
	assert(not (x * X))
end

return class
