local table_util = require("table_util")

local sql_util = {}

sql_util.NULL = {}

function sql_util.tohex(s)
	local out = {}
	for i = 1, #s do
		local c = s:sub(i, i)
		table.insert(out, ("%02x"):format(c:byte()))
	end
	return table.concat(out)
end

function sql_util.toboolean(v)
	if v == 0 then
		return false
	end
	return true
end

function sql_util.escape_literal(v)
	local tv = type(v)
	if v == sql_util.NULL then
		return "NULL"
	elseif tv == "boolean" then
		return v and 1 or 0
	elseif tv == "string" then
		return ("x'%s'"):format(sql_util.tohex(v))
	elseif tv == "number" then
		return ("%.20g"):format(v)
	elseif tv == "cdata" and tonumber(v) then
		return ("%.20g"):format(tonumber(v))
	end
	error(("unsupported type '%s'"):format(type(v)))
end

---@param s string|table
---@return string
function sql_util.escape_identifier(s)
	if type(s) == "table" then
		return s[1]
	end
	s = tostring(s)
	return '`' .. (s:gsub('`', '``')) .. '`'
end

local _format_cond = {
	contains = function(k, v)
		return ("%s LIKE %s"):format(
			sql_util.escape_identifier(k),
			sql_util.escape_literal("%" .. v .. "%")
		)
	end,
	startswith = function(k, v)
		return ("%s LIKE %s"):format(
			sql_util.escape_identifier(k),
			sql_util.escape_literal(v .. "%")
		)
	end,
	endswith = function(k, v)
		return ("%s LIKE %s"):format(
			sql_util.escape_identifier(k),
			sql_util.escape_literal("%" .. v)
		)
	end,
	["in"] = function(k, v)
		local _v = {}
		for i = 1, #v do
			_v[i] = sql_util.escape_literal(v[i])
		end
		return ("%s IN (%s)"):format(
			sql_util.escape_identifier(k),
			table.concat(_v, ", ")
		)
	end,
	notin = function(k, v)
		local _v = {}
		for i = 1, #v do
			_v[i] = sql_util.escape_literal(v[i])
		end
		return ("%s NOT IN (%s)"):format(
			sql_util.escape_identifier(k),
			table.concat(_v, ", ")
		)
	end,
	isnull = "%s IS NULL",
	isnotnull = "%s IS NOT NULL",
	eq = "%s = %s",
	ne = "%s != %s",
	gt = "%s > %s",
	gte = "%s >= %s",
	lt = "%s < %s",
	lte = "%s <= %s",
	regex = "%s REGEXP %s",
}

---@param op string
---@param k string
---@param v any
---@return string
local function format_cond(op, k, v)
	local fmt = _format_cond[op]
	if type(fmt) == "function" then
		return fmt(k, v)
	end
	return fmt:format(
		sql_util.escape_identifier(k),
		sql_util.escape_literal(v)
	)
end

---@param t table
---@return string?
function sql_util.build(t)
	local conds = {}

	for k, v in pairs(t) do
		if type(k) == "string" then
			local field, op = k:match("^(.+)__(.+)$")
			if not field then
				field, op = k, "eq"
			end
			table.insert(conds, format_cond(op, field, v))
		elseif type(v) == "table" then
			table.insert(conds, sql_util.build(v))
		end
	end

	if #conds == 0 then
		return
	end

	for i = 1, #conds do
		conds[i] = "(" .. conds[i] .. ")"
	end

	local op = t[1] == "or" and "OR" or "AND"
	return table.concat(conds, (" %s "):format(op))
end

---@param t table
---@param types table?
---@return table
function sql_util.for_db(t, types)
	local _t = {}
	for k, v in pairs(t) do
		if type(v) == "cdata" then
			v = tonumber(v)
		end
		local _type = types and types[k]
		if _type == "boolean" then
			v = v and 1 or 0
		elseif type(_type) == "table" then
			v = _type[v]
		end
		_t[k] = v
	end
	return _t
end

---@param t table
---@param types table?
---@return table
function sql_util.from_db(t, types)
	local _t = {}
	for k, v in pairs(t) do
		if type(v) == "cdata" then
			v = tonumber(v)
		end
		local _type = types and types[k]
		if _type == "boolean" then
			v = sql_util.toboolean(v)
		elseif type(_type) == "table" then
			v = table_util.keyof(_type, v)
		end
		_t[k] = v
	end
	return _t
end

return sql_util
