local mt = {}

---@alias util.Autoload {[1]: string, [2]: boolean, [string]: any}

---@param t util.Autoload
---@param k string
---@return any?
function mt.__index(t, k)
	local prefix, safe = t[1], t[2]
	local mod_name = prefix .. "." .. k
	---@type boolean, any
	local ok, mod = pcall(require, mod_name)
	if not safe then
		assert(ok, mod)
	elseif not ok then
		if not mod:match(("module '%s' not found"):format(mod_name)) then
			error(mod)
		end
		mod = true -- behave like empty file
	end
	t[k] = mod
	return mod
end

---@param prefix string
---@param safe boolean?
---@return util.Autoload
local function autoload(prefix, safe)
	return setmetatable({prefix, not not safe}, mt)
end

return autoload
