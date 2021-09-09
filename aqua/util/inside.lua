return function(t, key)
	local value = t
	if type(key) == "table" then
		for _, key in ipairs(key) do
			if type(value) ~= "table" then
				return
			end
			value = value[key]
		end
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
