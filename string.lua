string.trim = function(s)
	return s:match("^%s*(.-)%s*$")
end

string.split = function(s, divider, plain)
	local out = {}

	local pos = 0
	for a, b in function() return s:find(divider, pos, plain) end do
		out[#out + 1] = s:sub(pos, a - 1)
		pos = b + 1
	end
	out[#out + 1] = s:sub(pos)

	return out
end

return string
