local table_util = require("table_util")

local stbl = {}

stbl.allow_nan_inf = false

-- String-TaBLe / STaBLe
-- simple lua serializer with determined output

---@class stbl.ParseState
---@field pos integer
---@field str string

stbl.space = ""

stbl.enc = {}

---@param v number
---@return string
function stbl.enc.number(v)
	if not stbl.allow_nan_inf then
		if v ~= v then
			error("stbl: NaN not supported")
		elseif math.abs(v) == math.huge then
			error("stbl: infinity not supported")
		end
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
function stbl.enc.string(s)
	-- %c - control characters
	-- %z - zero byte
	local res = s:gsub("[%c\\\"\'%z]", function(c)
		return char_escape[c] or ("\\%03d"):format(c:byte())
	end)
	return '"' .. res .. '"'
end

---@param v boolean
---@return string
function stbl.enc.boolean(v)
	return tostring(v)
end

local keywords = table_util.invert({
	"and", "break", "do", "else", "elseif",
	"end", "false", "for", "function", "if",
	"in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until", "while",
})

---@param k string
---@return boolean
function stbl.is_plain_key(k)
	return k:match("^[%l%u_][%w_]*$") and not keywords[k]
end

---@param k string
---@return string
function stbl.skey(k)
	return stbl.is_plain_key(k) and k or ("[%s]"):format(stbl.enc.string(k))
end

---@param t table
---@param tables {[table]: boolean}
---@param safe boolean?
function stbl.enc.table(t, tables, safe)
	if tables[t] then
		return "nil"
	end

	---@type string[]
	local out = {}
	tables[t] = true

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
			table.insert(out, stbl.encode(v, tables, safe))
		else
			table.insert(out, "nil")
		end
	end

	local eq = ("%s=%s"):format(stbl.space, stbl.space)
	for _, k in ipairs(float_keys) do
		table.insert(out, ("[%s]%s%s"):format(stbl.encode(k, tables, safe), eq, stbl.encode(t[k], tables, safe)))
	end

	for _, k in ipairs(str_keys) do
		table.insert(out, ("%s%s%s"):format(stbl.skey(k), eq, stbl.encode(t[k], tables, safe)))
	end

	return "{" .. table.concat(out, "," .. stbl.space) .. "}"
end

---@param v any
---@param tables {[table]: boolean}?
---@param safe boolean?
---@return string
function stbl.encode(v, tables, safe)
	if v == nil then
		return ""
	end
	local tv = type(v)
	---@type function
	local encoder = stbl.enc[tv]
	if not encoder then
		if safe then return "nil" end
		error("unsupported value type '" .. tv .. "'")
	end
	tables = tables or {}
	return encoder(v, tables, safe)
end

---@param state stbl.ParseState
local function skip_whitespace(state)
	state.pos = state.str:find("%S", state.pos) or state.pos
end

---@param state stbl.ParseState
---@return any
local function parse_value(state)
	skip_whitespace(state)
	local c = state.str:sub(state.pos, state.pos)
	if c == "{" then return stbl._parse_table(state) end
	if c == '"' or c == "'" then return stbl._parse_string(state) end
	return stbl._parse_literal(state)
end

local escapes = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	['"'] = '"',
	["'"] = "'",
}

---@param state stbl.ParseState
---@return string
function stbl._parse_string(state)
	local quote = state.str:sub(state.pos, state.pos)
	state.pos = state.pos + 1
	local buffer = {}

	while state.pos <= #state.str do
		local c = state.str:sub(state.pos, state.pos)

		if c == "\\" then
			state.pos = state.pos + 1
			local next_c = state.str:sub(state.pos, state.pos)

			if escapes[next_c] then
				table.insert(buffer, escapes[next_c])
				state.pos = state.pos + 1
			elseif next_c:match("%d") then
				local digits = state.str:match("^%d%d?%d?", state.pos)
				local num = tonumber(digits)
				---@cast num -?
				table.insert(buffer, string.char(num))
				state.pos = state.pos + #digits
			else
				table.insert(buffer, "\\") -- fallback
			end
		elseif c == quote then
			state.pos = state.pos + 1
			return table.concat(buffer)
		else
			table.insert(buffer, c)
			state.pos = state.pos + 1
		end
	end
	error("stbl: unfinished string")
end

---@param state stbl.ParseState
---@return any
function stbl._parse_literal(state)
	local word = state.str:match("^[%w%.%-%/+]+", state.pos)

	if not word then error("stbl: unexpected character at " .. state.pos) end

	state.pos = state.pos + #word

	if word == "nil" then return nil end
	if word == "true" then return true end
	if word == "false" then return false end

	local n = tonumber(word)
	if not n then error("stbl: invalid literal '" .. word .. "'") end
	return n
end

---@param state stbl.ParseState
---@return table
function stbl._parse_table(state)
	---@type {[any]: any}
	local t = {}
	state.pos = state.pos + 1
	local array_idx = 1

	while true do
		skip_whitespace(state)
		local c = state.str:sub(state.pos, state.pos)

		if c == "}" then
			state.pos = state.pos + 1
			return t
		end

		---@type any, any
		local key, val
		if c == "[" then
			state.pos = state.pos + 1
			key = parse_value(state)
			state.pos = state.str:find("]", state.pos, true) + 1
			state.pos = state.str:find("=", state.pos, true) + 1
			val = parse_value(state)
		elseif state.str:match("^[%l%u_][%w_]*%s*=", state.pos) then
			key = state.str:match("^([%l%u_][%w_]*)", state.pos)
			state.pos = state.pos + #key
			state.pos = state.str:find("=", state.pos, true) + 1
			val = parse_value(state)
		else
			key = array_idx
			array_idx = array_idx + 1
			val = parse_value(state)
		end

		t[key] = val

		skip_whitespace(state)
		if state.str:sub(state.pos, state.pos) == "," then
			state.pos = state.pos + 1
		end
	end
end

function stbl.decode(v)
	if not v or v == "" then return nil end
	return parse_value({str = v, pos = 1})
end

return stbl
