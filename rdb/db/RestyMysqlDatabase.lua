---@class resty.mysql.Module
---@field new fun(self: resty.mysql.Module): resty.mysql.Connection?, string?

---@class resty.mysql.Connection
---@field connect fun(self: resty.mysql.Connection, options: table): true?, string?, integer?, string?
---@field close fun(self: resty.mysql.Connection): true?, string?
---@field query fun(self: resty.mysql.Connection, query: string): rdb.Row[]?, string?, integer?, string?

---@type resty.mysql.Module
local mysql = require("resty.mysql")
local MysqlDatabase = require("rdb.db.MysqlDatabase")
local sql_util = require("rdb.sql_util")

-- https://github.com/openresty/lua-resty-mysql

---@class rdb.RestyMysqlDatabase: rdb.MysqlDatabase
---@operator call: rdb.RestyMysqlDatabase
---@field db resty.mysql.Connection
local RestyMysqlDatabase = MysqlDatabase + {}

---@param db_name string
---@param username string
---@param password string
---@param hostname string
---@param port integer
---@return true?
---@return string?
function RestyMysqlDatabase:open(db_name, username, password, hostname, port)
	local db = assert(mysql:new())
	self.db = db

	local ok, err = db:connect({
		host = hostname,
		port = port,
		database = db_name,
		user = username,
		password = password,
		charset = "utf8",
		max_packet_size = 1024 * 1024,
	})
	if not ok then
		return nil, err
	end

	return true
end

function RestyMysqlDatabase:close()
	self.db:close()
end

---@param query string
---@param bind_vals any[]?
---@return fun(): integer?, rdb.Row?
function RestyMysqlDatabase:iter(query, bind_vals)
	if bind_vals then
		query = sql_util.bind(query, bind_vals, self.escape_literal)
	end

	local res = assert(self.db:query(query))

	local i = 0
	return function()
		i = i + 1
		---@type rdb.Row
		local row = res[i]
		if row then
			return i, row
		end
	end
end

return RestyMysqlDatabase
