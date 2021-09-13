local function outside(t, key, value)
	if type(key) ~= "string" or type(t) ~= "table" then
		return
	end
	local subvalue = t
	local prevValue
	local lastSubkey
	for subkey in key:gmatch("[^.]+") do
		if type(subvalue) ~= "table" then
			prevValue[lastSubkey] = {}
			subvalue = prevValue[lastSubkey]
		end
		prevValue = subvalue
		subvalue = subvalue[subkey]
		lastSubkey = subkey
	end
	prevValue[lastSubkey] = value
end

return outside
