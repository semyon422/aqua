local utf8 = {}

local check = function(s, i, patterns)
	for n = 1, #patterns do
		if i == string.find(s, patterns[n], i) then
			return true
		end
	end
end

utf8.validate = function(s)
	local i = 1
	while i <= #s do
		if check(s, i, {"[%z\1-\127]"}) then
			i = i + 1
		elseif check(s, i, {"[\194-\223][\123-\191]"}) then
			i = i + 2
		elseif check(s, i, {
				"\224[\160-\191][\128-\191]",
				"[\225-\236][\128-\191][\128-\191]",
				"\237[\128-\159][\128-\191]",
				"[\238-\239][\128-\191][\128-\191]"
			}) then
			i = i + 3
		elseif check(s, i, {
				"\240[\144-\191][\128-\191][\128-\191]",
				"[\241-\243][\128-\191][\128-\191][\128-\191]",
				"\244[\128-\143][\128-\191][\128-\191]"
			}) then
			i = i + 4
		else
			return "Invalid UTF-8 string"
		end
	end

	return s
end

return utf8
