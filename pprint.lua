local stbl = require("stbl")

---@overload fun(v: any)
local pprint = {}

pprint.colored = true

-- https://github.com/fidian/ansi
---@enum (key) pprint.Color
local colors = {
	reset = "\27[0m",
	bracket = "\27[38;5;230m",
	key = "\27[38;5;117m",
	type = "\27[38;5;78m",
	address = "\27[38;5;244m",
	number = "\27[38;5;228m",
	string = "\27[38;5;214m",
	boolean = "\27[38;5;75m",
}

---@param color pprint.Color
---@param text any
---@return string
local function c(color, text)
	if not pprint.colored then
		return text
	end
	return colors[color] .. tostring(text) .. colors.reset
end

function pprint.export()
	rawset(_G, "pprint", pprint)
end

setmetatable(pprint --[[@as table]], {__call = function(t, v)
	print(pprint.dump(v))
end})

local ARRAY_LIMIT = 10

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

	if pa ~= pb then return pa < pb end
	if ta == 'number' or ta == 'string' then return a < b end
	if ta == 'boolean' then return (not a) and b end
	return ("%p"):format(a) < ("%p"):format(b)
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
		return c("address", ("<function: %s:%s | %p>"):format(src, line, value))
	elseif t == "table" then
		if visited[value] then
			return c("address", ("<table (recursive): %p>"):format(value))
		end
		visited[value] = true

		local mt = getmetatable(value)

		if indent_level > 0 and mt then
			return c("address", ("<table (has mt): %p>"):format(value))
		end

		if next(value) == nil then
			return c("address", ("<table: %p> "):format(value)) .. c("bracket", "{}")
		end

		if is_array(value) then
			local parts = {}
			local len = #value
			if len <= ARRAY_LIMIT + 2 then
				for i = 1, len do
					table.insert(parts, pprint.dump(value[i], indent_level, visited))
				end
			else
				local half = math.floor(ARRAY_LIMIT / 2)
				for i = 1, half do
					table.insert(parts, pprint.dump(value[i], indent_level, visited))
				end
				table.insert(parts, c("address", ("<%d more>"):format(len - ARRAY_LIMIT)))
				for i = len - half + 1, len do
					table.insert(parts, pprint.dump(value[i], indent_level, visited))
				end
			end
			return c("bracket", "{") .. table.concat(parts, ", ") .. c("bracket", "}")
		end

		---@cast value {[any]: any}

		---@type string[]
		local keys = {}
		for k in pairs(value) do table.insert(keys, k) end
		table.sort(keys, sorter)

		---@type string[]
		local lines = {}
		table.insert(lines, c("address", ("<table: %p> "):format(value)) .. c("bracket", "{"))

		for _, k in ipairs(keys) do
			---@type string
			local key_str
			local kt = type(k)

			if kt == "string" then
				if stbl.is_plain_key(k) then
					key_str = c("key", k)
				else
					key_str = c("bracket", "[") .. c("string", stbl.encode(k)) .. c("bracket", "]")
				end
			elseif kt == "number" or kt == "boolean" then
				local clr = (kt == "number") and "number" or "boolean"
				key_str = c("bracket", "[") .. c(clr, stbl.encode(k)) .. c("bracket", "]")
			else
				key_str = c("bracket", "[") .. c("address", ("<%s: %p>"):format(kt, k)) .. c("bracket", "]")
			end

			local val_str = pprint.dump(value[k], indent_level + 1, visited)
			table.insert(lines, ("%s  %s = %s%s"):format(indent_str, key_str, val_str, c("bracket", ",")))
		end

		table.insert(lines, indent_str .. c("bracket", "}"))
		return table.concat(lines, "\n")
	elseif stbl.enc[t] then
		if t == "number" then
			if value == math.huge then return c("number", "math.huge")
			elseif value == -math.huge then return c("number", "-math.huge")
			elseif value ~= value then return c("number", "NaN")
			end
		end

		---@type any
		local val = stbl.enc[t](value)
		if t == "string" then return c("string", val) end
		if t == "number" then return c("number", val) end
		if t == "boolean" then return c("boolean", val) end
		return val
	else
		return c("address", ("<%s: %p>"):format(t, value))
	end
end

return pprint
