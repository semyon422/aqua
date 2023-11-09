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
		return ("cast(x'%s' as TEXT)"):format(sql_util.tohex(v))
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
		return ("%s LIKE ?"):format(sql_util.escape_identifier(k)), {"%" .. v .. "%"}
	end,
	startswith = function(k, v)
		return ("%s LIKE ?"):format(sql_util.escape_identifier(k)), {v .. "%"}
	end,
	endswith = function(k, v)
		return ("%s LIKE ?"):format(sql_util.escape_identifier(k)), {"%" .. v}
	end,
	["in"] = function(k, v)
		local _v = {}
		for i = 1, #v do
			_v[i] = "?"
		end
		return ("%s IN (%s)"):format(
			sql_util.escape_identifier(k),
			table.concat(_v, ", ")
		), v
	end,
	notin = function(k, v)
		local _v = {}
		for i = 1, #v do
			_v[i] = "?"
		end
		return ("%s NOT IN (%s)"):format(
			sql_util.escape_identifier(k),
			table.concat(_v, ", ")
		), v
	end,
	isnull = "%s IS NULL",
	isnotnull = "%s IS NOT NULL",
	eq = "%s = ?",
	ne = "%s != ?",
	gt = "%s > ?",
	gte = "%s >= ?",
	lt = "%s < ?",
	lte = "%s <= ?",
	regex = "%s REGEXP ?",
}

---@param op string
---@param k string
---@param v any
---@return string
---@return table
local function format_cond(op, k, v)
	local fmt = _format_cond[op]
	if type(fmt) == "function" then
		return fmt(k, v)
	end
	local cond = fmt:format(sql_util.escape_identifier(k))
	if cond:find("?") then
		return cond, {v}
	end
	return cond, {}
end

---@param cond string
---@param vals table
---@return string
function sql_util.bind(cond, vals)
	local n = 0
	local full_cond = cond:gsub("?", function()
		n = n + 1
		return sql_util.escape_literal(vals[n])
	end)
	return full_cond
end

---@param t table
---@return string
---@return table
function sql_util.conditions(t)
	local conds = {}
	local vals = {}

	for k, v in pairs(t) do
		local cd, vs
		if type(k) == "string" then
			local field, op = k:match("^(.+)__(.+)$")
			if not field then
				field, op = k, "eq"
			end
			cd, vs = format_cond(op, field, v)
		elseif type(v) == "table" then
			cd, vs = sql_util.conditions(v)
		end
		if cd then
			table.insert(conds, cd)
			for _, _v in ipairs(vs) do
				table.insert(vals, _v)
			end
		end
	end

	if #conds == 0 then
		return "", {}
	end

	for i = 1, #conds do
		conds[i] = "(" .. conds[i] .. ")"
	end

	local op = t[1] == "or" and "OR" or "AND"
	return table.concat(conds, (" %s "):format(op)), vals
end

---@param values table
---@return string
---@return table
function sql_util.assigns(values)
	local assigns = {}
	local vals = {}
	for k, v in pairs(values) do
		table.insert(assigns, ("%s = ?"):format(sql_util.escape_identifier(k)))
		table.insert(vals, v)
	end
	return table.concat(assigns, ", "), vals
end

local function for_db(v, _type)
	if type(v) == "cdata" then
		v = tonumber(v)
	end
	if _type == "boolean" then
		v = v and 1 or 0
	elseif type(_type) == "table" then
		v = _type.encode(v)
	end
	return v
end

---@param t table?
---@param types table?
---@return table
function sql_util.for_db(t, types)
	local _t = {}
	for k, v in pairs(t) do
		local _k = k:match("^(.-)__") or k
		local _type = types and types[_k]
		v = for_db(v, _type)
		if type(v) == "table" then
			for i, _v in ipairs(v) do
				v[i] = for_db(_v, _type)
			end
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
			v = _type.decode(v)
		end
		_t[k] = v
	end
	return _t
end

return sql_util
