local mysql = require("resty.mysql")
local MysqlDatabase = require("rdb.db.MysqlDatabase")
local sql_util = require("rdb.sql_util")

-- https://github.com/openresty/lua-resty-mysql

---@class rdb.RestyMysqlDatabase: rdb.MysqlDatabase
---@operator call: rdb.RestyMysqlDatabase
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

	local ok, err, errcode, sqlstate = db:connect({
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

	local res, err, errcode, sqlstate = assert(self.db:query(query))

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
