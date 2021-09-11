local function inside(t, key)
	local value = t
	if type(key) == "table" then
		for _, subkey in ipairs(key) do
			if type(subkey) == "table" then
				local k = subkey[1]
				local f = subkey[2]
				local v = inside(t, k)
				if v and f(t) then
					return v
				end
			elseif type(subkey) == "string" then
				local v = inside(t, subkey)
				if v then
					return v
				end
			end
		end
		return
	elseif type(key) == "string" then
		for subkey in key:gmatch("[^.]+") do
			if type(value) ~= "table" then
				return
			end
			value = value[subkey]
		end
	else
		return
	end
	return value
end

return inside
