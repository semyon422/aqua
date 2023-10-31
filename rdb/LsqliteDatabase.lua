local sqlite = require("lsqlite3")
local IDatabase = require("rdb.IDatabase")

---@class rdb.LsqliteDatabase: rdb.IDatabase
---@operator call: rdb.LsqliteDatabase
local LsqliteDatabase = IDatabase + {}

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
---@return table?
function LsqliteDatabase:query(query)
	local objects = {}
	for a in self.c:nrows(query) do
		table.insert(objects, a)
	end
	return objects
end

return LsqliteDatabase
