local synctable = {}

local function assertValueType(v)
	local t = type(v)
	assert(t == "string" or t == "number" or t == "table" or t == "boolean")
end

local function validate(t)
	for k, v in pairs(t) do
		local tk = type(k)
		assert(tk == "string" or tk == "number")
		assertValueType(v)
		if type(v) == "table" then
			validate(v)
		end
	end
end

local function getPath(t)
	local path = {}
	while t.__parent do
		table.insert(path, 1, t.__name)
		t = t.__parent
	end
	return path
end

local mt
mt = {
	__newindex = function(s, k, v)
		local _t = s.__t

		local path = getPath(s)
		if getmetatable(v) == mt then
			_t[k] = v.__t
			s.__cb(path, k, getPath(v), true)
			return
		elseif type(v) == "table" then
			local _v = _t[k]
			if _v ~= v then
				_v = {}
				_t[k] = _v
			end
			s.__cb(path, k, {})
			local _s = s[k]
			for _k, _v in pairs(v) do
				_s[_k] = _v
			end
			return
		end

		assertValueType(v)
		_t[k] = v
		s.__cb(path, k, v)
	end,
	__index = function(s, k)
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
	end,
}

function synctable.new(t, callback)
	validate(t)
	local res = setmetatable({
		__t = t,
		__cb = callback,
	}, mt)
	for k, v in pairs(t) do
		res[k] = v
	end
	return res
end

function synctable.set(object, path, k, v, isPath)
	local t = object
	for _, _k in ipairs(path) do
		t = t[_k]
	end

	if isPath then
		path = v
		v = object
		for _, _k in ipairs(path) do
			v = v[_k]
		end
	end

	t[k] = v
end

local function formatKey(key)
	local f = type(key) == "string" and ".%s" or "[%s]"
	return f:format(key)
end

local function formatPath(path)
	local p = {}
	for _, key in ipairs(path) do
		table.insert(p, formatKey(key))
	end
	return table.concat(p)
end

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

function synctable.format(prefix, path, k, v, isPath)
	return ("%s = %s"):format(
		prefix .. formatPath(path) .. formatKey(k),
		formatValue(prefix, v, isPath)
	)
end

return synctable
