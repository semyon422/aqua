
---@param t table
---@param ... any
---@return any
local function return_from_new(t, ...)
	if select("#", ...) > 0 then
		return ...
	end
	return t
end

---@param T {new: function?}
---@param ... any
---@return table
local function new(T, ...)
	local T_new = T.new
	if not T_new then
		local t = ... or {}
		assert(type(t) == "table" and not getmetatable(t), "bad argument to default constructor")
		return setmetatable(t, T)
	end

	local t = setmetatable({}, T)
	return return_from_new(t, T_new(t, ...))
end

---@param T table
---@return boolean
local function is_class(T)
	local mt = getmetatable(T)
	return not not (mt and mt.__is_class)
end

---@param t table
---@return boolean
local function is_instance(t)
	local T = getmetatable(t)
	return is_class(T)
end

---@param T table
---@param _T table
---@return boolean
local function type_of_class(T, _T)
	local mt = getmetatable(_T)
	if not mt or not mt.__is_class then
		return false
	end
	return mt.__parents[T] or false
end

---@param T table
---@param t table
---@return boolean
local function type_of_instance(T, t)
	local _T = getmetatable(t)
	if not _T then
		return false
	end
	return type_of_class(T, _T)
end

---@param p table?
---@param t table?
---@return table
local function class(p, t)
	if p then
		assert(is_class(p), "bad argument #1 to 'class'")
	end

	local mt = {
		__call = new,
		__add = class,
		__mul = type_of_instance,
		__div = type_of_class,
		__is_class = true,
	}

	local T = {}
	T.__index = T
	T.__name = debug.getinfo(2, "S").source

	---@type {[table]: true?}
	local parents = {[T] = true}
	if p then
		---@type {[table]: true}
		local parent_classes = getmetatable(p).__parents
		for parent in pairs(parent_classes) do
			parents[parent] = true
		end
	end

	if not is_class(t) then
		mt.__index = p
		mt.__parents = parents
		return setmetatable(T, mt)
	end

	---@type {[table]: true}
	local parent_classes = getmetatable(t).__parents
	for parent in pairs(parent_classes) do
		parents[parent] = true
	end
	mt.__parents = parents

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

setmetatable(M, {__call = function(_, p, t)
	return class(p, t)
end})

---@cast M +fun(p: table?, t: table?): table

return M
