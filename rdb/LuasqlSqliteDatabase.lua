local driver = require("luasql.sqlite3")
local IDatabase = require("rdb.IDatabase")
local sql_util = require("rdb.sql_util")

-- https://lunarmodules.github.io/luasql/manual.html

---@class rdb.LuasqlSqliteDatabase: rdb.IDatabase
---@operator call: rdb.LuasqlSqliteDatabase
local LuasqlSqliteDatabase = IDatabase + {}

---@param db string
function LuasqlSqliteDatabase:open(db)
	self.env = driver.sqlite3()
	self.c = self.env:connect(db)
end

function LuasqlSqliteDatabase:close()
	assert(self.c:close())
	assert(self.env:close())
end

---@param query string
function LuasqlSqliteDatabase:exec(query)
	self.c:execute(query)
end

---@param query string
---@param bind_vals any[]?
---@return fun(): integer?, rdb.Row?
function LuasqlSqliteDatabase:iter(query, bind_vals)
	if bind_vals then
		query = sql_util.bind(query, bind_vals)
	end

	local cur = assert(self.c:execute(query))

	---@type any[]
	local row = {}

	local i = 0
	return function()
		i = i + 1
		local row = cur:fetch(row, "a")
		if row then
			return i, row
		end
	end
end

---@param query string
---@param bind_vals any?
---@return rdb.Row[]
function LuasqlSqliteDatabase:query(query, bind_vals)
	---@type rdb.Row[]
	local objects = {}
	for i, obj in self:iter(query, bind_vals) do
		objects[i] = obj
	end
	return objects
end

return LuasqlSqliteDatabase
