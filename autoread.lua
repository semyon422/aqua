local mt = {}

---@param t {[string]: string}
---@param k string
---@return any?
function mt.__index(t, k)
	local f = assert(io.open(t.__path:format(k)))
	local s = f:read("*a")
	f:close()
	t[k] = s
	return s
end

return function(path)
	return setmetatable({__path = path}, mt)
end
