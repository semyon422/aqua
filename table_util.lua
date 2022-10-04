local table_util = {}

function table_util.leftequal(a, b)
	for key in pairs(a) do
		if a[key] ~= b[key] then
			return
		end
	end

	return true
end

function table_util.equal(a, b)
	return table.leftequal(a, b) and table.leftequal(b, a)
end

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

return table_util
