local IDatabase = require("rdb.db.IDatabase")
local sql_util = require("rdb.sql_util")

---@class rdb.SqliteDatabase: rdb.IDatabase
---@operator call: rdb.SqliteDatabase
local SqliteDatabase = IDatabase + {}

---@param table_name string
---@return string[]
function SqliteDatabase:columns(table_name)
	---@type string[]
	local columns = {}

	---@type {name: string}[]
	local info = self:query("PRAGMA table_info(" .. sql_util.escape_identifier(table_name) .. ")")
	for i, t in ipairs(info) do
		columns[i] = t.name
	end

	return columns
end

---@param ver integer?
---@return integer?
function SqliteDatabase:user_version(ver)
	if ver then
		self:query("PRAGMA user_version = " .. ver)
		return
	end
	local rows = self:query("PRAGMA user_version")
	return tonumber(rows[1].user_version)
end

return SqliteDatabase
