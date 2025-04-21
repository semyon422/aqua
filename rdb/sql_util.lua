local class = require("class")

local sql_util = {}

---@class sql_util.NULL
sql_util.NULL = {}

---@param s string
---@return string
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

---@param v any
---@return string|integer
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

---@param s string|{[1]: string}
---@return string
function sql_util.escape_identifier(s)
	if type(s) == "table" then
		return s[1]
	end
	s = tostring(s)
	return '`' .. (s:gsub('`', '``')) .. '`'
end

local esci = sql_util.escape_identifier

---@type {[string]: string|fun(k: string, v: any): string, any[]}
local _format_cond = {
	contains = function(k, v) return ("%s LIKE ?"):format(esci(k)), {"%" .. v .. "%"} end,
	notcontains = function(k, v) return ("%s NOT LIKE ?"):format(esci(k)), {"%" .. v .. "%"} end,
	startswith = function(k, v) return ("%s LIKE ?"):format(esci(k)), {v .. "%"} end,
	notstartswith = function(k, v) return ("%s NOT LIKE ?"):format(esci(k)), {v .. "%"} end,
	endswith = function(k, v) return ("%s LIKE ?"):format(esci(k)), {"%" .. v} end,
	notendswith = function(k, v) return ("%s NOT LIKE ?"):format(esci(k)), {"%" .. v} end,
	["in"] = function(k, v)
		---@type any[]
		local _v = {}
		for i = 1, #v do
			_v[i] = "?"
		end
		return ("%s IN (%s)"):format(esci(k), table.concat(_v, ", ")), v
	end,
	notin = function(k, v)
		---@type any[]
		local _v = {}
		for i = 1, #v do
			_v[i] = "?"
		end
		return ("%s NOT IN (%s)"):format(esci(k), table.concat(_v, ", ")), v
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
---@param ident boolean
---@return string?
---@return any[]
local function format_cond(op, k, v, ident)
	local fmt = _format_cond[op]
	if not fmt then
		error(("invalid operator '%s'"):format(op))
	end
	if type(fmt) == "function" then
		return fmt(k, v)
	end
	local has_binds = fmt:find("?") ~= nil
	if not has_binds and not v then  -- *__isnull = false
		return nil, {}
	end
	local cond = fmt:format(esci(k))
	if ident then
		cond = cond:gsub("?", "%%s"):format(esci(v))
		has_binds = false
	end
	if not has_binds then
		return cond, {}
	end
	return cond, {v}
end

---@param cond string
---@param vals any[]
---@return string
function sql_util.bind(cond, vals)
	local n = 0
	local full_cond = cond:gsub("?", function()
		n = n + 1
		return sql_util.escape_literal(vals[n])
	end)
	return full_cond
end

---@param t rdb.Conditions
---@return string
---@return any[]
function sql_util.conditions(t)
	---@type string[]
	local conds = {}
	local vals = {}

	for k, v in pairs(t) do
		---@type string?, any[]?
		local cd, vs
		if type(k) == "string" then
			local field, op, ident = k:match("^(.+)__([^_]+)(_?)$")
			if not field then
				field, ident = k:match("^(.-)(_?)$")
				op = "eq"
			end
			cd, vs = format_cond(op, field, v, ident == "_")
		elseif type(v) == "table" then
			cd, vs = sql_util.conditions(v)
		end
		if cd and vs then
			table.insert(conds, cd)
			for i, _v in ipairs(vs) do
				sql_util.assert_value(("%s (%d)"):format(cd, i), _v)
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

---@param values rdb.Row
---@return string
---@return any[]
function sql_util.assigns(values)
	local assigns = {}
	local vals = {}
	for k, v in pairs(values) do
		table.insert(assigns, ("%s = ?"):format(sql_util.escape_identifier(k)))
		table.insert(vals, v)
	end
	return table.concat(assigns, ", "), vals
end

---@param v any
---@param _type "boolean"|table?
---@return any
local function for_db(v, _type)
	if type(v) == "cdata" then
		v = tonumber(v)
	end
	if _type == "boolean" then
		v = v and 1 or 0
	elseif type(_type) == "table" then
		if class.is_instance(_type) then
			v = _type:encode(v) ---@diagnostic disable-line
		else
			v = _type.encode(v) ---@diagnostic disable-line
		end
	end
	return v
end

---@param t rdb.Conditions?
---@param types {[string]: "boolean"|table}?
---@return rdb.Conditions
function sql_util.conditions_for_db(t, types)
	---@type {[any]: any}
	local _t = {}
	if not t then
		return _t
	end
	for k, v in pairs(t) do
		if type(k) == "string" then
			local _k, op = k:match("^(.-)__(.+)$")
			if not _k then
				_k = k
			end

			local _type = types and types[_k]
			if op == "in" or op == "notin" then
				---@type any[]
				local _v = {}
				for i = 1, #v do
					_v[i] = for_db(v[i], _type)
				end
				v = _v
			elseif not op or op ~= "isnull" and op ~= "isnotnull" then
				v = for_db(v, _type)
			end
		elseif type(v) == "table" then
			v = sql_util.conditions_for_db(v, types)
		end
		_t[k] = v
	end
	return _t
end

---@generic T: any
---@param k string
---@param v T
---@return T
function sql_util.assert_value(k, v)
	local tv = type(v)
	if v ~= sql_util.NULL and tv ~= "number" and tv ~= "string" then
		error(("unexpected type '%s' for key '%s'"):format(tv, k))
	end
	return v
end

---@param t rdb.Row
---@param types {[string]: "boolean"|table}?
---@return rdb.Row
function sql_util.for_db(t, types)
	---@type rdb.Row
	local _t = {}
	for k, v in pairs(t) do
		local _type = types and types[k]
		_t[k] = for_db(v, _type)
	end
	return _t
end

---@param t rdb.Row
---@param types table?
---@return rdb.Row
function sql_util.from_db(t, types)
	---@type rdb.Row
	local _t = {}
	for k, v in pairs(t) do
		if type(v) == "cdata" then
			v = tonumber(v)
		end
		local _type = types and types[k]
		if _type == "boolean" then
			v = sql_util.toboolean(v)
		elseif type(_type) == "table" then
			if class.is_instance(_type) then
				v = _type:decode(v) ---@diagnostic disable-line
			else
				v = _type.decode(v) ---@diagnostic disable-line
			end
		end
		_t[k] = v
	end
	return _t
end

return sql_util
