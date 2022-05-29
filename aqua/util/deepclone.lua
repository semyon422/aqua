-- deep clone a table
local function deepclone(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = deepclone(v)
		else
			out[k] = v
		end
	end
	return out
end

return deepclone
