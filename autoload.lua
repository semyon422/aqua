local mt = {}

---@param t table
---@param mod_name string
---@return any?
function mt.__index(t, mod_name)
	local mod = require(t[1] .. "." .. mod_name)
	t[mod_name] = mod
	return mod
end

return function(prefix)
	return setmetatable({prefix}, mt)
end
