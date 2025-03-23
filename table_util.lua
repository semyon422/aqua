local table_util = {}

table_util.new = require("table.new")
table_util.clear = require("table.clear")

---@param a table
---@param b table
---@return boolean
function table_util.equal(a, b)
	local size, _size = 0, 0
	for k, v in pairs(a) do
		size = size + 1
		local _v = b[k]
		if v == v and v ~= _v then  -- nan check
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
			if not table_util.equal(v, _v) and not table_util.deepequal(v, _v) then
				return false
			end
		elseif v == v and v ~= _v then  -- nan check
			return false
		end
	end
	for _ in pairs(b) do
		_size = _size + 1
	end
	return size == _size
end

assert(table_util.deepequal({{}}, {{}}))

---@generic T
---@param src T?
---@param dst T?
---@return T
function table_util.copy(src, dst)
	if not src then
		return {}
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

---@param t table
---@param v any
---@param f function?
---@return number?
function table_util.indexof(t, v, f)
	for i, _v in ipairs(t) do
		if not f and _v == v or f and f(_v) == v then
			return i
		end
	end
end

---@param t table
---@param v any
---@param f function?
---@return any?
function table_util.keyof(t, v, f)
	for k, _v in pairs(t) do
		if not f and _v == v or f and f(_v) == v then
			return k
		end
	end
end

---@param t table
---@param k any
---@param v any
---@return any?
function table_util.value_by_field(t, k, v)
	for _, _v in pairs(t) do
		if _v[k] == v then
			return _v
		end
	end
end

---@generic K
---@generic V
---@param t {[K]: V}
---@return {[V]: K}
function table_util.invert(t)
	local _t = {}
	for k, v in pairs(t) do
		assert(not _t[v], "duplicate value '" .. tostring(v) .. "'")
		_t[v] = k
	end
	return _t
end

---@generic V
---@param t V[]
---@param append V[]
---@return V[]
function table_util.append(t, append)
	for i, v in ipairs(append) do
		table.insert(t, v)
	end
	return t
end

---@param t table
---@return number
function table_util.max_index(t)
	local max_i = 0
	for i in pairs(t) do
		if type(i) == "number" then
			max_i = math.max(max_i, i)
		end
	end
	return max_i
end

---@param t {[string]: number}
---@return string?
function table_util.keyofenum(t, v)
	if t[v] then
		return v
	end
	local k = table_util.keyof(t, tonumber(v))
	if type(k) == "string" then
		return k
	end
end

---@generic T
---@param a T
---@param _prev T?
---@param _next T?
function table_util.insert_linked(a, _prev, _next)
	a.prev, a.next = nil, nil
	if _prev then
		_prev.next = a
		a.prev = _prev
	end
	if _next then
		_next.prev = a
		a.next = _next
	end
end

---@generic T
---@param a T
---@return T?
---@return T?
function table_util.remove_linked(a)
	local prev, next = a.prev, a.next
	if prev then prev.next = next end
	if next then next.prev = prev end
	a.prev, a.next = nil, nil
	return prev, next
end

---@generic T
---@param t T[]
---@param pk string?
---@param nk string?
---@return T
function table_util.to_linked(t, pk, nk)
	pk = pk or "prev"
	nk = nk or "next"
	for i = 1, #t do
		t[i][pk] = t[i - 1]
		t[i][nk] = t[i + 1]
	end
	return t[1]
end

---@generic T
---@param head T
---@param unlink boolean?
---@param pk string?
---@param nk string?
---@return T[]
function table_util.to_array(head, unlink, pk, nk)
	pk = pk or "prev"
	nk = nk or "next"
	local t = {}
	local i = 0
	while head do
		i = i + 1
		t[i] = head
		local _next = head[nk]
		if unlink then
			head[pk] = nil
			head[nk] = nil
		end
		head = _next
	end
	return t
end

---@generic K, V
---@param t {[K]: V}
---@param k K
---@param f fun(...: any?): V
---@param ... any?
---@return V
function table_util.get_or_create(t, k, f, ...)
	local v = t[k]
	if v then
		return v
	end
	v = f(...)
	t[k] = v
	return v
end

---@param ... any
---@return any
function table_util.remove_holes(...)
	if select("#", ...) == 0 then
		return
	end
	if select(1, ...) == nil then
		return table_util.remove_holes(select(2, ...))
	end
	return select(1, ...), table_util.remove_holes(select(2, ...))
end

assert(table.concat({table_util.remove_holes(nil, 1, nil, 2, nil)}) == "12")

---@param graph {[any]: any[]}
---@return {[any]: any[]}
function table_util.invert_graph(graph)
	---@type {[any]: any[]}
	local _graph = {}
	for vert, verts in pairs(graph) do
		for _, _vert in ipairs(verts) do
			_graph[_vert] = _graph[_vert] or {}
			table.insert(_graph[_vert], vert)
		end
	end
	return _graph
end

---@param t any[]
---@param size integer
---@return any[][]
function table_util.slices(t, size)
	---@type any[][]
	local slices = {}
	local count = math.ceil(#t / size)
	for i = 1, count do
		slices[i] = table.move(t, size * (i - 1) + 1, size * i, 1, {})
	end
	return slices
end

assert(table_util.deepequal(
	table_util.slices({1, 2, 3, 4, 5, 6}, 2),
	{{1, 2}, {3, 4}, {5, 6}}
))
assert(table_util.deepequal(
	table_util.slices({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, 3),
	{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}, {10}}
))

---@generic T
---@param t {[T]: [any]}
---@return T
function table_util.keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

---@param t table
---@param f type|fun(v: any): boolean
---@return boolean
function table_util.is_array_of(t, f)
	if type(t) ~= "table" then
		return false
	end
	if type(f) == "string" then
		local _f = f
		f = function(v) return type(v) == _f end
	end
	---@cast t {[any]: [any]}
	local max_key = 0
	local count = 0
	for k, v in pairs(t) do
		if type(k) ~= "number" or k ~= math.floor(k) or k <= 0 or not f(v) then
			return false
		end
		count = count + 1
		max_key = math.max(max_key, k)
	end
	if count ~= max_key then
		return false
	end
	return true
end

assert(table_util.is_array_of({{1}}, function(v) return not not v[1] end))
assert(table_util.is_array_of({"q"}, "string"))
assert(table_util.is_array_of({1, 2, 3}, "number"))
assert(not table_util.is_array_of({[0] = 1, 2, 3}, "number"))
assert(not table_util.is_array_of({t = 1, 2, 3}, "number"))
assert(not table_util.is_array_of({1, nil, 3}, "number"))

return table_util
