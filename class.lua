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
		local t = ... or {}
		assert(type(t) == "table" and not getmetatable(t), "bad argument to default constructor")
		return setmetatable(t, T)
	end
	local t = setmetatable({}, T)
	return return_from_new_xpcall(t, xpcall(T.new, debug.traceback, t, ...))
end

---@param T table
---@return boolean
local function is_class(T)
	local mt = getmetatable(T)
	return not not (mt and mt.__call)
end

---@param t table
---@return boolean
local function is_instance(t)
	local T = getmetatable(t)
	return is_class(T)
end

local function type_of_class(T, _T)
	if not _T or not is_class(_T) then
		return false
	end
	if _T == T then
		return true
	end

	local mt = getmetatable(_T)
	if not mt.__indexes then
		return type_of_class(T, mt.__index)
	end

	---@type table, table
	local p, t = unpack(mt.__indexes)
	return type_of_class(T, p) or type_of_class(T, t)
end

local function type_of_instance(T, t)
	if not is_instance(t) then
		return false
	end
	local _T = getmetatable(t)
	return type_of_class(T, _T)
end

local function class(p, t)
	if p then
		assert(is_class(p), "bad argument #1 to 'class'")
	end

	local mt = {
		__call = new,
		__add = class,
		__mul = type_of_instance,
		__div = type_of_class,
	}

	local T = {}
	T.__index = T
	T.__name = debug.getinfo(2, "S").source

	if not is_class(t) then
		mt.__index = p
		return setmetatable(T, mt)
	end

	mt.__indexes = {p, t}
	function mt.__index(_, k)
		---@type any, any
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
	assert(is_class(A))
	assert(not is_instance(A))

	local a = A() ---@type any
	assert(is_instance(a))
	assert(not is_class(a))

	assert(A / A)
	assert(not (A * A))
	assert(A * a)
	assert(not (A / a))
end

do
	local A = class()
	local B = A + {} ---@type any

	local a = A() ---@type any
	local b = B() ---@type any

	assert(A / A)
	assert(A / B)
	assert(B / B)
	assert(not (B / A))

	assert(A * a)
	assert(A * b)
	assert(B * b)
	assert(not (B * a))
end

do
	local A = class()
	local B = class()
	local C = class()
	local X = A + B + C ---@type any

	local x = X() ---@type any

	assert(A / X)
	assert(B / X)
	assert(C / X)
	assert(X * x)

	assert(not (X / A))
	assert(not (X / B))
	assert(not (X / C))
	assert(not (x * X))
	assert(not (X / x))
end

local M = {
	is_class = is_class,
	is_instance = is_instance,
}

setmetatable(M, {__call = class})

---@cast M +fun(p: table?, t: table?): table

return M
