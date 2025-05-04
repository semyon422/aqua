local driver = require("luasql.mysql")
local MysqlDatabase = require("rdb.db.MysqlDatabase")
local sql_util = require("rdb.sql_util")

-- https://lunarmodules.github.io/luasql/manual.html

---@class rdb.LuasqlMysqlDatabase: rdb.MysqlDatabase
---@operator call: rdb.LuasqlMysqlDatabase
local LuasqlMysqlDatabase = MysqlDatabase + {}

---@param db string
---@param username string
---@param password string
---@param hostname string
---@param port integer
---@return true?
---@return string?
function LuasqlMysqlDatabase:open(db, username, password, hostname, port)
	self.env = driver.mysql()
	local c, err = self.env:connect(db, username, password, hostname, port)
	if not c then
		return nil, err
	end
	self.c = c
	return true
end

function LuasqlMysqlDatabase:close()
	assert(self.c:close())
	assert(self.env:close())
end

---@param query string
---@param bind_vals any[]?
---@return fun(): integer?, rdb.Row?
function LuasqlMysqlDatabase:iter(query, bind_vals)
	if bind_vals then
		query = sql_util.bind(query, bind_vals, self.escape_literal)
	end

	local cur = assert(self.c:execute(query))
	if type(cur) == "number" then
		return function() end
	end

	local i = 0
	return function()
		i = i + 1
		---@type rdb.Row
		local row = cur:fetch({}, "a")
		if row then
			return i, row
		end
	end
end

return LuasqlMysqlDatabase
