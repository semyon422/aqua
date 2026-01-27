local stbl = require("stbl")

---@overload fun(v: any)
local pprint = {}

function pprint.export()
	_G.pprint = pprint
end

setmetatable(pprint --[[@as table]], {__call = function(t, v)
	print(pprint.dump(v))
end})

local ARRAY_LIMIT = 10

---@param v any
---@return string
local function get_addr(v)
	if v == nil then return "nil" end
	return ("%p"):format(v)
end

local type_priority = {
	['boolean'] = 1,
	['number'] = 2,
	['string'] = 3,
	['function'] = 4,
	['table'] = 5,
	['userdata'] = 6,
	['thread'] = 7,
}

---@param a any
---@param b any
---@return boolean
local function sorter(a, b)
	local ta, tb = type(a), type(b)
	local pa, pb = type_priority[ta] or 0, type_priority[tb] or 0

	if pa ~= pb then
		return pa < pb
	end

	if ta == 'number' or ta == 'string' then
		return a < b
	elseif ta == 'boolean' then
		return (not a) and b -- false < true
	else
		return get_addr(a) < get_addr(b)
	end
end

---@param t any
---@return boolean
local function is_array(t)
	if type(t) ~= "table" then return false end
	---@cast t any[]
	local i = 0
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false end
	end
	return i > 0
end

---@param value any
---@param indent_level integer?
---@param visited {[table]: true}?
---@return string
function pprint.dump(value, indent_level, visited)
	indent_level = indent_level or 0
	visited = visited or {}

	local t = type(value)
	local indent_str = string.rep("  ", indent_level)

	if t == "function" then
		local info = debug.getinfo(value, "S")
		local src = info and info.short_src or "C"
		local line = info and info.linedefined or -1
		return ("<function: %s:%d | %s>"):format(src, line, get_addr(value))
	elseif t == "table" then
		if visited[value] then
			return "<table (recursive): " .. get_addr(value) .. ">"
		end
		visited[value] = true

		local addr = get_addr(value)
		local mt = getmetatable(value)

		if indent_level > 0 and mt then
			return ("<table (has mt): %s>"):format(addr)
		end

		if next(value) == nil then
			return ("<table: %s> {}"):format(addr)
		end

		if is_array(value) then
			---@cast value any[]

			---@type string[]
			local parts = {}
			local len = #value

			if len <= ARRAY_LIMIT + 2 then
				for i, v in ipairs(value) do
					table.insert(parts, pprint.dump(v, indent_level + 1, visited))
				end
			else
				local half = math.floor(ARRAY_LIMIT / 2)
				for i = 1, half do
					table.insert(parts, pprint.dump(value[i], indent_level + 1, visited))
				end
				table.insert(parts, ("<%d more>"):format(len - ARRAY_LIMIT))
				for i = len - half + 1, len do
					table.insert(parts, pprint.dump(value[i], indent_level + 1, visited))
				end
			end
			return ("{%s}"):format(table.concat(parts, ", "))
		end

		---@cast value {[any]: any}

		---@type string[]
		local keys = {}
		for k in pairs(value) do table.insert(keys, k) end
		table.sort(keys, sorter)

		---@type string[]
		local lines = {}
		table.insert(lines, ("<table: %s> {"):format(addr))

		for _, k in ipairs(keys) do
			---@type string
			local key_str
			local kt = type(k)

			if kt == "string" then
				key_str = stbl.skey(k)
			elseif kt == "number" or kt == "boolean" then
				key_str = ("[%s]"):format(stbl.encode(k))
			else
				key_str = ("[<%s: %s>]"):format(kt, get_addr(k))
			end

			local v = value[k]
			local val_str = pprint.dump(v, indent_level + 1, visited)
			table.insert(lines, ("%s  %s = %s,"):format(indent_str, key_str, val_str))
		end

		table.insert(lines, indent_str .. "}")
		return table.concat(lines, "\n")
	elseif stbl.enc[t] then
		return stbl.enc[t](value)
	else
		return ("<%s: %s>"):format(t, get_addr(value))
	end
end

return pprint
