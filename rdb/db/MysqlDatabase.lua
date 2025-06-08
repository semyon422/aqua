local IDatabase = require("rdb.db.IDatabase")
local sql_util = require("rdb.sql_util")

---@class rdb.MysqlDatabase: rdb.IDatabase
---@operator call: rdb.MysqlDatabase
local MysqlDatabase = IDatabase + {}

---@param table_name string
---@return string[]
function MysqlDatabase:columns(table_name)
	---@type string[]
	local columns = {}

	---@type {Field: string}[]
	local info = self:query(("DESCRIBE %s;"):format(table_name))
	for i, t in ipairs(info) do
		columns[i] = t.Field
	end

	return columns
end

---@param v any
---@return string|integer
function MysqlDatabase.escape_literal(v)
	local tv = type(v)
	if tv == "string" then
		return ("x'%s'"):format(sql_util.tohex(v))
	end
	return sql_util.escape_literal(v)
end

return MysqlDatabase
