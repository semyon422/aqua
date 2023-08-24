local table_util = {}

---@param a table
---@param b table
---@return boolean
function table_util.equal(a, b)
	local size, _size = 0, 0
	for k, v in pairs(a) do
		size = size + 1
		local _v = b[k]
		if v ~= _v then
			return false
		end
	end
	for _ in pairs(b) do
		_size = _size + 1
	end
	return size == _size
end

---@param a table
---@param b table
---@return boolean
function table_util.deepequal(a, b)
	local size, _size = 0, 0
	for k, v in pairs(a) do
		size = size + 1
		local _v = b[k]
		if type(v) == "table" and type(_v) == "table" then
			if not table_util.deepequal(v, _v) then
				return false
			end
		elseif v ~= _v then
			return false
		end
	end
	for _ in pairs(b) do
		_size = _size + 1
	end
	return size == _size
end

assert(table_util.deepequal({{}}, {{}}))

---@param src table?
---@param dst table?
---@return table?
function table_util.copy(src, dst)
	if not src then
		return
	end
	dst = dst or {}
	for k, v in pairs(src) do
		dst[k] = v
	end
	return dst
end

---@param t table
---@return table
function table_util.deepcopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = table_util.deepcopy(v)
		else
			out[k] = v
		end
	end
	return out
end

---@param new table
---@param old table
---@param new_f function?
---@param old_f function?
---@return table
---@return table
---@return table
function table_util.array_update(new, old, new_f, old_f)
	local _new = {}
	for _, v in ipairs(new) do
		if new_f then v = new_f(v) end
		_new[v] = true
	end

	local _old = {}
	for _, v in ipairs(old) do
		if old_f then v = old_f(v) end
		_old[v] = true
	end

	new = {}
	old = {}
	local all = {}
	for v in pairs(_new) do
		if not _old[v] then
			table.insert(new, v)
		end
		table.insert(all, v)
	end
	for v in pairs(_old) do
		if not _new[v] then
			table.insert(old, v)
		end
	end

	return new, old, all
end

---@param t table
---@param key any?
---@return any?
function table_util.inside(t, key)
	local subvalue = t
	if type(key) == "table" then
		for _, subkey in ipairs(key) do
			if type(subkey) == "table" then
				local k = subkey[1]
				local f = subkey[2]
				local v = table_util.inside(t, k)
				if v and f(t) then
					return v
				end
			elseif type(subkey) == "string" then
				local v = table_util.inside(t, subkey)
				if v then
					return v
				end
			end
		end
		return
	elseif type(key) == "string" then
		for subkey in key:gmatch("[^.]+") do
			if type(subvalue) ~= "table" then
				return
			end
			subvalue = subvalue[subkey]
		end
		return subvalue
	end
end

---@param ... any?
---@return table
function table_util.pack(...)
	return {n = select("#", ...), ...}
end

---@param f function
---@param index number?
---@return function
function table_util.cache(f, index)
	local cache = {}
	return function(...)
		local k = select(index or 1, ...)
		local t = cache[k]
		if t then
			return unpack(t, 1, t.n)
		end
		t = table_util.pack(f(...))
		cache[k] = t
		return unpack(t, 1, t.n)
	end
end

return table_util
