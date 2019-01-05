local _string = string

local string = {}

setmetatable(_string, {
	__index = string
})

string.trim = function(s)
	return s:match("^%s*(.-)%s*$")
end

string.split = function(s, divider, plain)
	local position = 0
	local output = {}
	
	for endchar, startchar in function() return s:find(divider, position, plain) end do
		output[#output + 1] = s:sub(position, endchar - 1)
		position = startchar + 1
	end
	output[#output + 1] = s:sub(position)
	
	return output
end

string.mirror = function(s)
	local out = {}
	for i = 1, #s do
		out[#s + 1 - i] = s:sub(i, i)
	end
	return table.concat(out)
end

return string