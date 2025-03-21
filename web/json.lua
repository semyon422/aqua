local json_module

for _, mod in ipairs({"cjson", "json"}) do
	local ok, json = pcall(require, mod)
	if ok then
		json_module = json
	end
end

assert(json_module, "modules 'cjson' or 'json' not found")

local json = {}

---@param t any
---@return string
function json.encode(t)
	return json_module.encode(t)
end

---@param s string
---@return any
function json.decode(s)
	return json_module.decode(s)
end

---@param s string
---@return any?
---@return string?
function json.decode_safe(s)
	---@type boolean, any
	local ok, ret = pcall(json_module.decode, s)
	if not ok then
		return nil, ret
	end
	return ret
end

return json
