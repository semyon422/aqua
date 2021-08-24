return function(t, fields)
	local value = t
	if type(fields) == "table" then
		for _, key in ipairs(fields) do
			if type(value) ~= "table" then
				return
			end
			value = value[key]
		end
	elseif type(fields) == "string" then
		for key in fields:gmatch("[^.]+") do
			if type(value) ~= "table" then
				return
			end
			value = value[key]
		end
	else
		return
	end
	return value
end
