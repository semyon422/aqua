local sqlite = require("lsqlite3")
local SqliteDatabase = require("rdb.db.SqliteDatabase")
local sql_util = require("rdb.sql_util")

-- http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki

---@class rdb.LsqliteDatabase: rdb.SqliteDatabase
---@operator call: rdb.LsqliteDatabase
local LsqliteDatabase = SqliteDatabase + {}

---@param db string
function LsqliteDatabase:open(db)
	self.c = sqlite.open(db)
end

function LsqliteDatabase:close()
	self.c:close()
end

---@param query string
function LsqliteDatabase:exec(query)
	self.c:exec(query)
end

---@param query string
---@param bind_vals any[]?
---@return fun(): integer?, rdb.Row?
function LsqliteDatabase:iter(query, bind_vals)
	local stmt = self.c:prepare(query)
	if bind_vals then
		for i, v in ipairs(bind_vals) do
			if v ~= sql_util.NULL then
				stmt:bind(i, v)
			end
		end
	end

	local next_row, svm = stmt:nrows()
	local i = 0
	return function()
		i = i + 1
		local row = next_row(svm)
		if row then
			return i, row
		end
	end
end

return LsqliteDatabase
