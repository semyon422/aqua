rawset(_G, 'sqlite3', false) -- _G write guard warning fix

---@class lsqlite3.Statement
---@field bind fun(self: lsqlite3.Statement, index: integer, value: any)
---@field nrows fun(self: lsqlite3.Statement): fun(state: any): rdb.Row?, any

---@class lsqlite3.Connection
---@field close fun(self: lsqlite3.Connection)
---@field exec fun(self: lsqlite3.Connection, query: string)
---@field prepare fun(self: lsqlite3.Connection, query: string): lsqlite3.Statement

---@type {open: fun(path: string): lsqlite3.Connection}
local sqlite = require("lsqlite3")
local SqliteDatabase = require("rdb.db.SqliteDatabase")
local sql_util = require("rdb.sql_util")

-- http://lua.sqlite.org/index.cgi/doc/tip/doc/lsqlite3.wiki

---@class rdb.LsqliteDatabase: rdb.SqliteDatabase
---@operator call: rdb.LsqliteDatabase
---@field c lsqlite3.Connection
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

	local iterator = {stmt:nrows()}
	---@type fun(state: any): rdb.Row?
	local next_row = iterator[1]
	-- LuaLS 3.19 leaves the state return unknown for this external iterator API.
	---@diagnostic disable-next-line: no-unknown
	local svm = iterator[2]
	local i = 0
	return function()
		i = i + 1
		---@type rdb.Row?
		local row = next_row(svm)
		if row then
			return i, row
		end
	end
end

return LsqliteDatabase
