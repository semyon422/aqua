local synctable = {}

---@param src table
---@param dst table
local function copy(src, dst)
	for k, v in pairs(src) do
		dst[k] = v
	end
end

---@param t table
---@param path table
---@return table
local function deep_index(t, path)
	for _, k in ipairs(path) do
		t = t[k]
	end
	return t
end

---@param v string|number|table|boolean|nil
local function assert_value_type(v)
	local t = type(v)
	assert(t == "string" or t == "number" or t == "table" or t == "boolean" or t == "nil")
end

---@param t table
local function validate(t)
	for k, v in pairs(t) do
		local tk = type(k)
		assert(tk == "string" or tk == "number")
		assert_value_type(v)
		if type(v) == "table" then
			validate(v)
		end
	end
end

---@param t table
---@return table
local function get_path(t)
	local path = {}
	while t.__parent do
		table.insert(path, 1, t.__name)
		t = t.__parent
	end
	return path
end

local mt = {}

---@param s table
---@param k string|number
---@param v string|number|table|boolean|nil
function mt.__newindex(s, k, v)
	local _t = s.__t
	local path = get_path(s)

	if type(v) ~= "table" then
		assert_value_type(v)
		_t[k] = v
		s.__cb(path, k, v)
		return
	end

	if getmetatable(v) == mt then
		_t[k] = v.__t
		s.__cb(path, k, get_path(v), true)
		return
	end

	local _v = _t[k]
	if _v ~= v then
		_v = {}
		_t[k] = _v
	end
	s.__cb(path, k, {})

	copy(v, s[k])
end

---@param s table
---@param k string|number
---@return string|number|table|boolean|nil
function mt.__index(s, k)
	local _t = s.__t
	local v = _t[k]
	local _v = rawget(s, v)

	if type(v) ~= "table" then
		return v
	elseif _v then
		return _v
	end

	_v = setmetatable({
		__t = v,
		__name = k,
		__parent = s,
		__cb = s.__cb,
	}, mt)
	rawset(s, v, _v)

	return _v
end

---@param t table
---@param callback function
---@return table
function synctable.new(t, callback)
	validate(t)
	local res = setmetatable({  -- set mt before copy
		__t = t,
		__cb = callback,
	}, mt)
	copy(t, res)  -- will call callback
	return res
end

---@param object table
---@param path table
---@param k any
---@param v any
---@param isPath boolean?
function synctable.set(object, path, k, v, isPath)
	local t = deep_index(object, path)

	if isPath then
		v = deep_index(object, v)
	end

	t[k] = v
end

---@param key any
local function formatKey(key)
	local f = type(key) == "string" and ".%s" or "[%s]"
	return f:format(key)
end

---@param path table
local function formatPath(path)
	local p = {}
	for _, key in ipairs(path) do
		table.insert(p, formatKey(key))
	end
	return table.concat(p)
end

---@param prefix string
---@param value any
---@param isPath boolean?
local function formatValue(prefix, value, isPath)
	if isPath then
		return prefix .. formatPath(value)
	end
	if type(value) == "table" then
		return "{}"
	elseif type(value) == "string" then
		return ("%q"):format(value)
	end
	return value
end

---@param prefix string
---@param path table
---@param k any
---@param v any
---@param isPath boolean?
function synctable.format(prefix, path, k, v, isPath)
	return ("%s = %s"):format(
		prefix .. formatPath(path) .. formatKey(k),
		formatValue(prefix, v, isPath)
	)
end

return synctable
