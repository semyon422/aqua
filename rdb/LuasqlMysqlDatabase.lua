local driver = require("luasql.mysql")
local IDatabase = require("rdb.IDatabase")
local sql_util = require("rdb.sql_util")

-- https://lunarmodules.github.io/luasql/manual.html

---@class rdb.LuasqlMysqlDatabase: rdb.IDatabase
---@operator call: rdb.LuasqlMysqlDatabase
local LuasqlMysqlDatabase = IDatabase + {}

---@param db string
---@param username string
---@param password string
---@param hostname string
---@param port integer
function LuasqlMysqlDatabase:open(db, username, password, hostname, port)
	self.env = driver.mysql()
	self.c = self.env:connect(db, username, password, hostname, port)
end

function LuasqlMysqlDatabase:close()
	assert(self.c:close())
	assert(self.env:close())
end

---@param query string
function LuasqlMysqlDatabase:exec(query)
	self.c:execute(query)
end

---@param v any
---@return string|integer
local function escape_literal(v)
	local tv = type(v)
	if tv == "string" then
		return ("x'%s'"):format(sql_util.tohex(v))
	end
	return sql_util.escape_literal(v)
end

---@param query string
---@param bind_vals any[]?
---@return fun(): integer?, rdb.Row?
function LuasqlMysqlDatabase:iter(query, bind_vals)
	if bind_vals then
		query = sql_util.bind(query, bind_vals, escape_literal)
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
function LuasqlMysqlDatabase:query(query, bind_vals)
	---@type rdb.Row[]
	local objects = {}
	for i, obj in self:iter(query, bind_vals) do
		objects[i] = obj
	end
	return objects
end

return LuasqlMysqlDatabase
