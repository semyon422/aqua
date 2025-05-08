local class = require("class")
local table_util = require("table_util")
local sql_util = require("rdb.sql_util")
local PrintDatabase = require("rdb.db.PrintDatabase")

---@alias rdb.Row {[string]: any}
---@alias rdb.Conditions {[string]: any?, [integer]: rdb.Conditions?, [1]: "or"?}
---@alias rdb.Options {columns: string[]?, order: string[]?, group: string[]?, limit: integer?, format: string?}

---@class rdb.TableOrm
---@operator call: rdb.TableOrm
local TableOrm = class()

---@param db rdb.IDatabase
function TableOrm:new(db)
	self.db = db
	---@type {[string]: string[]}
	self.table_columns = {}
end

---@param dbg boolean
function TableOrm:debug(dbg)
	if dbg and not self.debugging then
		self.db = PrintDatabase(self.db)
		self.debugging = true
	else
		self.db = self.db.db
		self.debugging = false
	end
end

---@param table_name string
---@return string[]
function TableOrm:columns(table_name)
	local columns = self.table_columns[table_name]
	if columns then
		return columns
	end
	columns = self.db:columns(table_name)
	self.table_columns[table_name] = columns
	return columns
end

---@param query string
---@param bind_vals any[]?
---@return rdb.Row[]
function TableOrm:query(query, bind_vals)
	if not query:upper():find("^%s*SELECT") then
		query = query .. " RETURNING *"
	end
	return self.db:query(query, bind_vals)
end

function TableOrm:begin()
	self.db:exec("BEGIN")
end

function TableOrm:commit()
	self.db:exec("COMMIT")
end

local default_options = {
	columns = {"*"},
	order = nil,
	group = nil,
	limit = nil,
	format = nil,
}

---@param table_name string
---@param conditions rdb.Conditions?
---@param options rdb.Options?
---@return rdb.Row[]
function TableOrm:select(table_name, conditions, options)
	local opts = options or default_options
	local columns = opts.columns or default_options.columns

	local postfix = {}
	---@type string, any[]
	local conds, vals

	if conditions and next(conditions) then
		conds, vals = sql_util.conditions(conditions)
		table.insert(postfix, "WHERE " .. conds)
	end
	if opts.group then
		table.insert(postfix, "GROUP BY " .. table.concat(opts.group, ", "))
	end
	if opts.order then
		table.insert(postfix, "ORDER BY " .. table.concat(opts.order, ", "))
	end
	if opts.limit then
		table.insert(postfix, "LIMIT " .. opts.limit)
	end

	---@type string
	local from
	if table_name:upper():match("^%s*SELECT") or table_name:find("\n") then -- subquery
		from = ("(%s) AS subquery"):format(table_name)
	else
		from = sql_util.escape_identifier(table_name)
	end

	local q = ("SELECT %s FROM %s %s"):format(
		table.concat(columns, ", "),
		from,
		table.concat(postfix, " ")
	)

	if opts.format then
		q = opts.format:format(q)
	end

	return self:query(q, vals)
end

---@param table_name string
---@param values_array rdb.Row[]
---@param ignore boolean?
---@return rdb.Row[]
function TableOrm:insert(table_name, values_array, ignore)
	local columns = assert(self:columns(table_name), "no such table: " .. table_name)
	assert(#values_array > 0, "missing values")

	---@type {[string]: true?}
	local keys_map = {}
	for _, values in ipairs(values_array) do
		for key in pairs(values) do
			keys_map[key] = true
		end
	end

	---@type string[]
	local keys_list = {}
	for _, key in ipairs(columns) do
		if keys_map[key] then
			table.insert(keys_list, key)
		end
	end

	assert(#keys_list > 0, "missing values")

	---@type string[]
	local query_keys = {}
	for i, key in ipairs(keys_list) do
		query_keys[i] = sql_util.escape_identifier(key)
	end
	local keys = ("(%s)"):format(table.concat(query_keys, ", "))

	local values_q0 = ("(%s)"):format(("?, "):rep(#keys_list - 1) .. "?")
	local values_q = (values_q0 .. ", "):rep(#values_array - 1) .. values_q0

	local c = 0
	---@type any[]
	local query_values = {}
	for _, values in ipairs(values_array) do
		for i, key in ipairs(keys_list) do
			local value = values[key]
			c = c + 1
			if value then
				query_values[c] = value
			else
				query_values[c] = sql_util.NULL
			end
			sql_util.assert_value(key, query_values[c])
		end
	end

	return self:query(("INSERT%s INTO %s %s VALUES %s"):format(
		ignore and " OR IGNORE" or "",
		sql_util.escape_identifier(table_name),
		keys, values_q
	), query_values)
end

---@param table_name string
---@param values rdb.Row
---@param conditions rdb.Conditions?
---@return rdb.Row[]
function TableOrm:update(table_name, values, conditions)
	local columns = assert(self:columns(table_name), "no such table: " .. table_name)

	---@type {[string]: any}
	local filtered_values = {}
	for _, key in ipairs(columns) do
		local value = values[key]
		if value ~= nil then
			filtered_values[key] = value
			sql_util.assert_value(key, value)
		end
	end
	if not next(filtered_values) then
		return {}
	end
	local assigns, vals_a = sql_util.assigns(filtered_values)

	if not conditions or not next(conditions) then
		return self:query(("UPDATE %s SET %s"):format(
			sql_util.escape_identifier(table_name),
			assigns
		), vals_a)
	end

	local conds, vals_b = sql_util.conditions(conditions)

	---@type any[]
	local vals = {}
	for _, v in ipairs(vals_a) do
		table.insert(vals, v)
	end
	for _, v in ipairs(vals_b) do
		table.insert(vals, v)
	end

	return self:query(("UPDATE %s SET %s WHERE %s"):format(
		sql_util.escape_identifier(table_name),
		assigns, conds
	), vals)
end

---@param table_name string
---@param conditions rdb.Conditions?
---@return rdb.Row[]
function TableOrm:delete(table_name, conditions)
	if not conditions or not next(conditions) then
		return self:query(("DELETE FROM %s"):format(
			sql_util.escape_identifier(table_name)
		))
	end

	local conds, vals = sql_util.conditions(conditions)
	return self:query(("DELETE FROM %s WHERE %s"):format(
		sql_util.escape_identifier(table_name),
		conds
	), vals)
end

---@param table_name string
---@param conditions rdb.Conditions?
---@param options rdb.Options?
---@return integer
function TableOrm:count(table_name, conditions, options)
	local opts = table_util.copy(options) or {}
	opts.format = ("SELECT COUNT(*) as c FROM (%s)"):format(opts.format or "%s")
	return self:select(table_name, conditions, opts)[1].c
end

return TableOrm
