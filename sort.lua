return function(...)
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
