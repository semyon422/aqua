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
	while t.__name do
		table.insert(path, 1, t.__name)
		t = t.__parent
	end
	return path
end

function synctable.new(t, callback)
	validate(t)
	local mt
	mt = {
		__newindex = function(s, k, v)
			local _t = s.__t

			local path = getPath(s)
			if getmetatable(v) == mt then
				_t[k] = v.__t
				callback(path, k, getPath(v), true)
				return
			elseif type(v) == "table" then
				local _v = {}
				_t[k] = _v
				callback(path, k, _v)
				local _s = s[k]
				for _k, _v in pairs(v) do
					_s[_k] = _v
				end
				return
			end

			assertValueType(v)
			_t[k] = v
			callback(path, k, v)
		end,
		__index = function(s, k)
			local _t = s.__t
			local v = _t[k]
			local _v = rawget(s, v)
			if type(v) == "table" then
				if not _v then
					_v = setmetatable({
						__t = v,
						__name = k,
						__parent = s,
					}, mt)
					rawset(s, v, _v)
				end
				return _v
			else
				return v
			end
		end,
	}
	local res = setmetatable({__t = t}, mt)
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

return synctable
