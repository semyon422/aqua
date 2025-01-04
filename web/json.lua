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

return json
