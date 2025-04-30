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

function encoders.string(v)
	return (("%q"):format(v):gsub("\n", "n"))
end

function encoders.boolean(v)
	return tostring(v)
end

local keywords = {
	"and", "break", "do", "else", "elseif",
	"end", "false", "for", "function", "if",
	"in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until", "while",
}

for _, keyword in ipairs(keywords) do
	keywords[keyword] = true
end

local function tkey(k)
	local plain = k:match("^[%l%u_][%w_]*$") and not keywords[k]
	return plain and k or ("[%s]"):format(encoders.string(k))
end

---@param t table
---@param tables {[table]: number, count: number}
function encoders.table(t, tables)
	if tables[t] then
		return ("tables[%d]"):format(tables[t])
	end

	local out = {}
	tables.count = tables.count + 1
	tables[t] = tables.count

	if next(t) == nil then
		return "{}"
	end

	local max_int_key = 0
	local float_keys = {}
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
			table.insert(out, ("%s"):format(stbl.encode(v, tables)))
		else
			table.insert(out, "nil")
		end
	end

	local eq = ("%s=%s"):format(stbl.space, stbl.space)
	for _, k in ipairs(float_keys) do
		table.insert(out, ("[%s]%s%s"):format(stbl.encode(k, tables), eq, stbl.encode(t[k], tables)))
	end

	for _, k in ipairs(str_keys) do
		table.insert(out, ("%s%s%s"):format(tkey(k), eq, stbl.encode(t[k], tables)))
	end

	return table.concat({"{", table.concat(out, "," .. stbl.space), "}"})
end

---@param v any
---@param tables {[table]: number, count: number}?
---@return string
function stbl.encode(v, tables)
	if v == nil then
		return ""
	end
	local encoder = encoders[type(v)]
	if not encoder then
		error("unsupported value type '" .. type(v) .. "'")
	end
	tables = tables or {count = 0}
	return encoder(v, tables)
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
