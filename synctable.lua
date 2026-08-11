local synctable = {}

---@alias synctable.Key string|number
---@alias synctable.Value string|number|boolean|synctable.Data|nil
---@alias synctable.Data {[synctable.Key]: synctable.Value}
---@alias synctable.Callback fun(path: synctable.Key[], key: synctable.Key, value: synctable.Value|synctable.Key[], is_path: boolean)

---@class synctable.Proxy
---@field __t synctable.Data
---@field __name synctable.Key?
---@field __parent synctable.Proxy?
---@field __cb synctable.Callback

---@param src synctable.Data
---@param dst synctable.Data
local function copy(src, dst)
	-- LuaLS 3.19 does not propagate dictionary key/value types through pairs().
	---@diagnostic disable-next-line: no-unknown
	for k, v in pairs(src) do
		dst[k] = v
	end
end

---@param t synctable.Data
---@param path synctable.Key[]
---@return synctable.Data
local function deep_index(t, path)
	for _, k in ipairs(path) do
		-- LuaLS 3.19 loses recursive union types on loop reassignment.
		---@diagnostic disable-next-line: no-unknown
		t = assert(t[k])
		---@cast t synctable.Data
	end
	return t
end

---@param v synctable.Value
local function assert_value_type(v)
	local t = type(v)
	assert(t == "string" or t == "number" or t == "table" or t == "boolean" or t == "nil")
end

---@param t synctable.Data
local function validate(t)
	-- LuaLS 3.19 does not propagate dictionary key/value types through pairs().
	---@diagnostic disable-next-line: no-unknown
	for k, v in pairs(t) do
		local tk = type(k)
		assert(tk == "string" or tk == "number")
		assert_value_type(v)
		if type(v) == "table" then
			validate(v)
		end
	end
end

---@param t synctable.Proxy
---@return synctable.Key[]
local function get_path(t)
	---@type synctable.Key[]
	local path = {}
	while t.__parent do
		table.insert(path, 1, t.__name)
		t = t.__parent
	end
	return path
end

local mt = {}

---@param s synctable.Proxy
---@param k synctable.Key
---@param v synctable.Value
function mt.__newindex(s, k, v)
	local _t = s.__t
	local path = get_path(s)

	if type(v) ~= "table" then
		assert_value_type(v)
		_t[k] = v
		s.__cb(path, k, v, false)
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
	s.__cb(path, k, {}, false)

	copy(v, s[k])
end

---@param s synctable.Proxy
---@param k synctable.Key
---@return synctable.Value
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

---@param t synctable.Data
---@param callback synctable.Callback
---@return synctable.Proxy
function synctable.new(t, callback)
	validate(t)
	local res = setmetatable({ -- set mt before copy
		__t = t,
		__cb = callback,
	}, mt)
	copy(t, res) -- will call callback
	return res
end

---@param object table
---@param path synctable.Key[]
---@param k synctable.Key
---@param v synctable.Value|synctable.Key[]
---@param is_path boolean
function synctable.set(object, path, k, v, is_path)
	local t = deep_index(object, path)

	if is_path then
		---@cast v synctable.Key[]
		v = deep_index(object, v)
	end

	t[k] = v
end

---@param key any
---@return string
local function formatKey(key)
	local f = type(key) == "string" and ".%s" or "[%s]"
	return f:format(key)
end

---@param path synctable.Key[]
---@return string
local function formatPath(path)
	---@type string[]
	local p = {}
	for _, key in ipairs(path) do
		table.insert(p, formatKey(key))
	end
	return table.concat(p)
end

---@param prefix string
---@param value any
---@param is_path boolean
---@return string
local function formatValue(prefix, value, is_path)
	if is_path then
		return prefix .. formatPath(value)
	end
	if type(value) == "table" then
		return "{}"
	elseif type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

---@param prefix string
---@param path synctable.Key[]
---@param k synctable.Key
---@param v synctable.Value|synctable.Key[]
---@param is_path boolean
---@return string
function synctable.format(prefix, path, k, v, is_path)
	return ("%s = %s"):format(
		prefix .. formatPath(path) .. formatKey(k),
		formatValue(prefix, v, is_path)
	)
end

return synctable
