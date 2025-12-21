local table_util = {}

table_util.new = require("table.new")
table_util.clear = require("table.clear")

---@generic T: table
---@param t T
---@param keys any[]
---@return T
function table_util.sub(t, keys)
	---@type {[any]: any}
	local _t = {}
	for _, k in ipairs(keys) do
		_t[k] = t[k]
	end
	return _t
end

---@param a {[any]: any}
---@param b {[any]: any}
---@return boolean
function table_util.equal(a, b)
	local size, _size = 0, 0
	for k, v in pairs(a) do
		size = size + 1
		local _v = b[k]
		if v == v and v ~= _v then -- nan check
			return false
		end
	end
	for _ in pairs(b) do
		_size = _size + 1
	end
	return size == _size
end

---@param a {[any]: any}
---@param b {[any]: any}
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
		elseif v == v and v ~= _v then -- nan check
			return false
		end
	end
	for _ in pairs(b) do
		_size = _size + 1
	end
	return size == _size
end

assert(table_util.deepequal({{}}, {{}}))

---@param ta table
---@param tb table
---@param keys string[]
---@param t_eq (fun(a: table, b: table): boolean)?
---@return boolean
function table_util.subequal(ta, tb, keys, t_eq)
	for _, k in ipairs(keys) do
		---@type any, any
		local a, b = ta[k], tb[k]
		if t_eq and type(a) == "table" and type(b) == "table" then
			if not t_eq(a, b) then
				return false
			end
		elseif a ~= b then
			return false
		end
	end
	return true
end

assert(not table_util.subequal({a = 1, b = 3, 0}, {a = 1, b = 2}, {"a", "b"}))
assert(table_util.subequal({a = 1, b = 2, 0}, {a = 1, b = 2}, {"a", "b"}))

assert(not table_util.subequal({a = {1, 2}, 0}, {a = {1, 2}}, {"a"}))
assert(not table_util.subequal({a = {1, 2}, 0}, {a = {1, 3}}, {"a"}, table_util.deepequal))
assert(table_util.subequal({a = {1, 2}, 0}, {a = {1, 2}}, {"a"}, table_util.deepequal))

---@generic T: table
---@param src T?
---@param dst T?
---@return T
function table_util.copy(src, dst)
	if not src then
		return {}
	end
	---@type {[any]: any}
	dst = dst or {}
	---@cast src {[any]: any}
	for k, v in pairs(src) do
		dst[k] = v
	end
	return dst
end

---@generic T: table
---@param t T
---@return T
function table_util.deepcopy(t)
	if type(t) ~= "table" then
		return t
	end
	---@type {[any]: any}
	local out = {}
	---@cast t {[any]: any}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = table_util.deepcopy(v)
		else
			out[k] = v
		end
	end
	return out
end

---@generic T
---@param new T[]
---@param old T[]
---@param new_f (fun(v: T): T)?
---@param old_f (fun(v: T): T)?
---@return T[]
---@return T[]
---@return T[]
function table_util.array_update(new, old, new_f, old_f)
	---@cast new any[]
	---@cast old any[]

	---@type {[any]: true}
	local _new = {}
	for _, v in ipairs(new) do
		if new_f then v = new_f(v) end
		_new[v] = true
	end

	---@type {[any]: true}
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

---@generic T
---@param new T[]
---@param old T[]
---@return T[]
---@return T[]
function table_util.array_update2(new, old)
	---@cast new any[]
	---@cast old any[]

	---@type {[any]: true}
	local _new = {}
	for _, v in ipairs(new) do
		_new[v] = true
	end

	---@type {[any]: true}
	local _old = {}
	for _, v in ipairs(old) do
		_old[v] = true
	end

	---@type any[]
	new = {}
	for v in pairs(_new) do
		if not _old[v] then
			table.insert(new, v)
		end
	end

	---@type any[]
	old = {}
	for v in pairs(_old) do
		if not _new[v] then
			table.insert(old, v)
		end
	end

	return new, old
end

---@param t table
---@param key (string|[string, function])[]|string?
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
			---@type any
			subvalue = subvalue[subkey]
		end
		return subvalue
	end
end

---@generic T
---@param t T[]
---@param i integer?
---@param j integer?
---@return T? ...
---@nodiscard
function table_util.unpack(t, i, j)
	i = i or 1
	j = j or t.n or #t
	if i > j then
		return
	end
	return t[i], unpack(t, i + 1, j)
end

assert(table_util.equal({table_util.unpack({1, 2, 3})}, {1, 2, 3}))
assert(table_util.equal({table_util.unpack({1, 2, 3}, 2, 2)}, {2}))

---@generic T
---@param ... T?
---@return {n: integer, [integer]: T}
function table_util.pack(...)
	return {n = select("#", ...), ...}
end

---@generic T: function
---@param f T
---@param index number?
---@return T
function table_util.cache(f, index)
	---@type {[any]: any[]}
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

---@generic T
---@param t T[]
---@param v T
---@param f (fun(v: T): T)?
---@return number?
function table_util.indexof(t, v, f)
	---@cast t any[]
	for i, _v in ipairs(t) do
		if not f and _v == v or f and f(_v) == v then
			return i
		end
	end
end

---@generic K, V
---@param t {[K]: V}
---@param v V
---@param f (fun(v: V): V)?
---@return K?
function table_util.keyof(t, v, f)
	---@cast t {[any]: any}
	for k, _v in pairs(t) do
		if not f and _v == v or f and f(_v) == v then
			return k
		end
	end
end

---@generic K
---@generic V
---@param t {[K]: V}
---@return {[V]: K}
function table_util.invert(t)
	---@cast t {[any]: any}
	---@type {[any]: any}
	local _t = {}
	for k, v in pairs(t) do
		assert(not _t[v], "duplicate value '" .. tostring(v) .. "'")
		_t[v] = k
	end
	return _t
end

---@generic T
---@param t T[]
---@param append T[]
---@return T[]
function table_util.append(t, append)
	---@cast t {[any]: any}
	---@cast append {[any]: any}
	for i, v in ipairs(append) do
		table.insert(t, v)
	end
	return t
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

---@class table_util.LinkedNode
---@field prev table_util.LinkedNode?
---@field next table_util.LinkedNode?

---@generic T
---@param a T
---@param _prev T?
---@param _next T?
function table_util.insert_linked(a, _prev, _next)
	---@cast a table_util.LinkedNode
	---@cast _prev table_util.LinkedNode
	---@cast _next table_util.LinkedNode
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
	---@cast a table_util.LinkedNode
	local prev, next = a.prev, a.next
	if prev then prev.next = next end
	if next then next.prev = prev end
	a.prev, a.next = nil, nil
	return prev, next
end

---@generic T
---@param t T[]
---@return T
function table_util.to_linked(t)
	---@cast t table_util.LinkedNode[]
	for i = 1, #t do
		t[i].prev = t[i - 1] ---@diagnostic disable-line: no-unknown
		t[i].next = t[i + 1] ---@diagnostic disable-line: no-unknown
	end
	return t[1]
end

---@generic T
---@param head T
---@param unlink boolean?
---@return T[]
function table_util.to_array(head, unlink)
	---@cast head table_util.LinkedNode
	---@type any[]
	local t = {}
	local i = 0
	while head do
		i = i + 1
		t[i] = head
		local _next = head.next
		if unlink then
			head.prev = nil
			head.next = nil
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
	---@type any
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
---@param t {[T]: any}
---@return T[]
function table_util.keys(t)
	---@cast t {[any]: any}
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


---@param n integer
---@param m integer?
---@return integer[]
function table_util.range(n, m)
	---@type integer[]
	local t = {}

	if not m then
		n, m = 1, n
	end

	for i = n, m do
		t[i - n + 1] = i
	end

	return t
end

assert(table_util.equal(table_util.range(3), {1, 2, 3}))
assert(table_util.equal(table_util.range(2, 4), {2, 3, 4}))

---@generic T
---@param ... T
---@return fun(a: T, b: T): boolean
function table_util.sortby(...)
	local t = {...}
	return function(a, b)
		for i = 1, #t do
			local ti = t[i]
			if a[ti] ~= b[ti] then
				return a[ti] < b[ti]
			end
		end
	end
end


return table_util
