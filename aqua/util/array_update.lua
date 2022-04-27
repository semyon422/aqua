return function(new, old, new_f, old_f)
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
