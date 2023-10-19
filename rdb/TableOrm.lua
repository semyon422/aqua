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
	assert(info)
	for _, t in ipairs(info) do
		t.cid = tonumber(t.cid)
		t.notnull = tonumber(t.notnull) ~= 0
		t.pk = tonumber(t.pk) ~= 0
	end
	self.table_infos[table_name] = info
	return info
end

---@param table_name string
---@param conditions table?
---@return table
function TableOrm:select(table_name, conditions)
	return self.db:query(("SELECT * FROM %s %s"):format(
		sql_util.escape_identifier(table_name),
		conditions and "WHERE " .. sql_util.build(conditions) or ""
	)) or {}
end

---@param table_name string
---@param values table
---@param ignore boolean?
---@return table?
function TableOrm:insert(table_name, values, ignore)
	local table_info = assert(self:table_info(table_name), "no such table: " .. table_name)

	local count = 0
	local query_keys = {}
	local query_values = {}
	for _, column in ipairs(table_info) do
		local key = column.name
		local value = values[key]
		if value then
			count = count + 1
			query_keys[count] = sql_util.escape_identifier(key)
			query_values[count] = sql_util.escape_literal(value)
		end
	end

	local keys = ("(%s)"):format(table.concat(query_keys, ", "))
	local _values = ("(%s)"):format(table.concat(query_values, ", "))

	return self.db:query(("INSERT%s INTO %s %s VALUES %s RETURNING *"):format(
		ignore and " OR IGNORE" or "",
		sql_util.escape_identifier(table_name),
		keys,
		_values
	))
end

---@param table_name string
---@param values table
---@param conditions table?
function TableOrm:update(table_name, values, conditions)
	local table_info = assert(self:table_info(table_name), "no such table: " .. table_name)

	local assigns = {}
	for _, column in ipairs(table_info) do
		local key = column.name
		local value = values[key]
		if value ~= nil then
			table.insert(assigns, ("%s = %s"):format(
				sql_util.escape_identifier(key), sql_util.escape_literal(value)
			))
		end
	end

	if not conditions then
		self.db:query(("UPDATE %s SET %s"):format(
			sql_util.escape_identifier(table_name),
			table.concat(assigns, ", ")
		))
		return
	end

	self.db:query(("UPDATE %s SET %s WHERE %s"):format(
		sql_util.escape_identifier(table_name),
		table.concat(assigns, ", "),
		sql_util.build(conditions)
	))
end

---@param table_name string
---@param conditions table?
function TableOrm:delete(table_name, conditions)
	self.db:query(("DELETE FROM %s %s"):format(
		sql_util.escape_identifier(table_name),
		conditions and "WHERE " .. sql_util.build(conditions) or ""
	))
end

return TableOrm
