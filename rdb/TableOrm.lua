local class = require("class")
local sql_util = require("rdb.sql_util")

---@class rdb.TableOrm
---@operator call: rdb.TableOrm
local TableOrm = class()

---@param db rdb.IDatabase
function TableOrm:new(db)
	self.db = db
	self.table_infos = {}
end

---@param table_name string
---@return table?
function TableOrm:table_info(table_name)
	local info = self.table_infos[table_name]
	if info then
		return info
	end
	info = self.db:query("PRAGMA table_info(" .. sql_util.escape_identifier(table_name) .. ")")
	for _, t in ipairs(info) do
		t.cid = tonumber(t.cid)
		t.notnull = tonumber(t.notnull) ~= 0
		t.pk = tonumber(t.pk) ~= 0
	end
	self.table_infos[table_name] = info
	return info
end

---@param ver number?
---@return number?
function TableOrm:user_version(ver)
	if ver then
		self.db:query("PRAGMA user_version = " .. ver)
		return
	end
	local rows = self.db:query("PRAGMA user_version")
	return tonumber(rows[1].user_version)
end

local default_options = {
	columns = "*",
	order = nil,
	limit = nil,
}

---@param table_name string
---@param conditions table?
---@param options table?
---@return table
function TableOrm:select(table_name, conditions, options)
	options = options or default_options
	local columns = options.columns or default_options.columns
	local order = options.order or default_options.order
	local limit = options.limit or default_options.limit

	local postfix = {}
	if order then
		table.insert(postfix, "ORDER BY " .. table.concat(order, ", "))
	end
	if limit then
		table.insert(postfix, "LIMIT " .. limit)
	end

	if not conditions or not next(conditions) then
		return self.db:query(("SELECT %s FROM %s"):format(
			columns,
			sql_util.escape_identifier(table_name)
		))
	end

	local conds, vals = sql_util.conditions(conditions)
	return self.db:query(("SELECT %s FROM %s WHERE %s"):format(
		columns,
		sql_util.escape_identifier(table_name),
		conds
	), vals)
end

---@param table_name string
---@param values_array table
---@param ignore boolean?
---@return table
function TableOrm:insert(table_name, values_array, ignore)
	local table_info = assert(self:table_info(table_name), "no such table: " .. table_name)
	assert(#values_array > 0, "missing values")

	local keys_map = {}
	for _, values in ipairs(values_array) do
		for key in pairs(values) do
			keys_map[key] = true
		end
	end

	local keys_list = {}
	for _, column in ipairs(table_info) do
		local key = column.name
		if keys_map[key] then
			table.insert(keys_list, key)
		end
	end

	local query_keys = {}
	for i, key in ipairs(keys_list) do
		query_keys[i] = sql_util.escape_identifier(key)
	end
	local keys = ("(%s)"):format(table.concat(query_keys, ", "))

	local values_q0 = ("(%s)"):format(("?, "):rep(#keys_list - 1) .. "?")
	local values_q = (values_q0 .. ", "):rep(#values_array - 1) .. values_q0

	local c = 0
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
		end
	end

	return self.db:query(("INSERT%s INTO %s %s VALUES %s RETURNING *"):format(
		ignore and " OR IGNORE" or "",
		sql_util.escape_identifier(table_name),
		keys, values_q
	), query_values)
end

---@param table_name string
---@param values table
---@param conditions table?
---@return table
function TableOrm:update(table_name, values, conditions)
	local table_info = assert(self:table_info(table_name), "no such table: " .. table_name)

	local filtered_values = {}
	for _, column in ipairs(table_info) do
		local key = column.name
		local value = values[key]
		if value ~= nil then
			filtered_values[key] = value
		end
	end
	if not next(filtered_values) then
		return {}
	end
	local assigns, vals_a = sql_util.assigns(filtered_values)

	if not conditions or not next(conditions) then
		return self.db:query(("UPDATE %s SET %s RETURNING *"):format(
			sql_util.escape_identifier(table_name),
			assigns, vals_a
		))
	end

	local conds, vals_b = sql_util.conditions(conditions)

	local vals = {}
	for _, v in ipairs(vals_a) do
		table.insert(vals, v)
	end
	for _, v in ipairs(vals_b) do
		table.insert(vals, v)
	end

	return self.db:query(("UPDATE %s SET %s WHERE %s RETURNING *"):format(
		sql_util.escape_identifier(table_name),
		assigns, conds
	), vals)
end

---@param table_name string
---@param conditions table?
---@return table
function TableOrm:delete(table_name, conditions)
	if not conditions or not next(conditions) then
		return self.db:query(("DELETE FROM %s RETURNING *"):format(
			sql_util.escape_identifier(table_name)
		))
	end

	local conds, vals = sql_util.conditions(conditions)
	return self.db:query(("DELETE FROM %s WHERE %s RETURNING *"):format(
		sql_util.escape_identifier(table_name),
		conds
	), vals)
end

---@param table_name string
---@param conditions table?
---@return number
function TableOrm:count(table_name, conditions)
	local options = {columns = "COUNT(1) as c"}
	return self:select(table_name, conditions, options)[1].c
end

return TableOrm
