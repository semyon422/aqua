local function sort(a, b)
	local ta, tb = type(a), type(b)
	local na, nb = ta == "number", tb == "number"
	if na and nb then
		return a < b
	elseif na or nb then
		return na and not nb
	end
	return tostring(a) < tostring(b)
end

return function(t)
	local _t = {}
	for k in pairs(t) do
		table.insert(_t, k)
	end
	table.sort(_t, sort)

	local i = 0
	return function()
		i = i + 1
		return _t[i], t[_t[i]]
	end
end
