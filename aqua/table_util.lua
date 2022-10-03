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

return table_util
