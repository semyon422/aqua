local ffi = require("ffi")
local table_util = require("table_util")

local stbl = {}

-- String-TaBLe / STaBLe
-- simple lua serializer with determined output

stbl.space = ""

local encoders = {}

function encoders.number(v)
	if v ~= v then
		return "0/0"
	elseif v == math.huge then
		return "1/0"
	elseif v == -math.huge then
		return "-1/0"
	end
	return ("%.17g"):format(v)
end


local char_escape = {
	["\\"] = "\\\\",
	["\a"] = "\\a",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\v"] = "\\v",
	["\""] = "\\\"",
	["\'"] = "\\\'",
	["\0"] = "\\0",
}

---@param s string
---@return string
function encoders.string(s)
	-- %c - control characters
	-- %z - zero byte
	local res = s:gsub("[%c\\\"\'%z]", function(c)
		return char_escape[c] or ("\\%03d"):format(c:byte())
	end)
	return '"' .. res .. '"'
end

function encoders.boolean(v)
	return tostring(v)
end

encoders["ctype<int64_t>"] = function(v)
	return tostring(v)
end

encoders["ctype<uint64_t>"] = function(v)
	return tostring(v)
end

local keywords = table_util.invert({
	"and", "break", "do", "else", "elseif",
	"end", "false", "for", "function", "if",
	"in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until", "while",
})

local function tkey(k)
	local plain = k:match("^[%l%u_][%w_]*$") and not keywords[k]
	return plain and k or ("[%s]"):format(encoders.string(k))
end

---@param t table
---@param tables {[table]: number, count: number}
---@param safe boolean?
function encoders.table(t, tables, safe)
	if tables[t] then
		return ("tables[%d]"):format(tables[t])
	end

	---@type string[]
	local out = {}
	tables.count = tables.count + 1
	tables[t] = tables.count

	if next(t) == nil then
		return "{}"
	end

	---@cast t {[any]: any}

	local max_int_key = 0

	---@type number[]
	local float_keys = {}

	---@type string[]
	local str_keys = {}

	for k in pairs(t) do
		if type(k) == "number" then
			if k > 0 and k % 1 == 0 then
				max_int_key = math.max(max_int_key, k)
			else
				table.insert(float_keys, k)
			end
		elseif type(k) == "string" then
			table.insert(str_keys, k)
		else
			error("unsupported key type '" .. type(k) .. "'")
		end
	end
	table.sort(float_keys)
	table.sort(str_keys)

	for i = 1, max_int_key do
		local v = t[i]
		if v ~= nil then
			table.insert(out, ("%s"):format(stbl.encode(v, tables, safe)))
		else
			table.insert(out, "nil")
		end
	end

	local eq = ("%s=%s"):format(stbl.space, stbl.space)
	for _, k in ipairs(float_keys) do
		table.insert(out, ("[%s]%s%s"):format(stbl.encode(k, tables, safe), eq, stbl.encode(t[k], tables, safe)))
	end

	for _, k in ipairs(str_keys) do
		table.insert(out, ("%s%s%s"):format(tkey(k), eq, stbl.encode(t[k], tables, safe)))
	end

	return table.concat({"{", table.concat(out, "," .. stbl.space), "}"})
end

---@param v any
---@param tables {[table]: number, count: number}?
---@param safe boolean?
---@return string
function stbl.encode(v, tables, safe)
	if v == nil then
		return ""
	end
	local tv = type(v)
	if tv == "cdata" then
		tv = tostring(ffi.typeof(v))
	end
	---@type function
	local encoder = encoders[tv]
	if not encoder then
		if safe then
			return ("%q"):format(v)
		end
		error("unsupported value type '" .. tv .. "'")
	end
	tables = tables or {count = 0}
	return encoder(v, tables, safe)
end

---@param v string
---@param chunkname string?
---@return any
function stbl.decode(v, chunkname)
	local env = {}
	local f = assert(load(("return %s"):format(v), chunkname, "t"))
	setfenv(f, env)
	return f()
end

return stbl
