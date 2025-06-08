local sqlite = require("ljsqlite3")
local SqliteDatabase = require("rdb.db.SqliteDatabase")
local sql_util = require("rdb.sql_util")

---@class rdb.LjsqliteDatabase: rdb.SqliteDatabase
---@operator call: rdb.LjsqliteDatabase
local LjsqliteDatabase = SqliteDatabase + {}

---@param db string
function LjsqliteDatabase:open(db)
	self.c = sqlite.open(db)
end

function LjsqliteDatabase:close()
	self.c:close()
end

---@param row any[]
---@param colnames string[]
---@return rdb.Row
local function to_object(row, colnames)
	---@type rdb.Row
	local t = {}
	for i, k in ipairs(colnames) do
		t[k] = row[i]
	end
	return t
end

---@param query string
---@param bind_vals any[]?
---@return fun(): integer?, rdb.Row?
function LjsqliteDatabase:iter(query, bind_vals)
	local stmt = self.c:prepare(query)
	if bind_vals then
		for i, v in ipairs(bind_vals) do
			if v == sql_util.NULL then
				v = nil
			end
			stmt:bind1(i, v)
		end
	end

	---@type string[]
	local colnames = {}
	local i = 0
	---@type any[]
	local row = {}

	return function()
		i = i + 1
		---@type any[]
		row = stmt:step(row, colnames)

		if row then
			return i, to_object(row, colnames)
		end

		stmt:close()
	end
end

return LjsqliteDatabase
