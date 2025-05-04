local IDatabase = require("rdb.db.IDatabase")
local stbl = require("stbl")

---@class rdb.PrintDatabase: rdb.IDatabase
---@operator call: rdb.PrintDatabase
local PrintDatabase = IDatabase + {}

---@param db rdb.IDatabase
function PrintDatabase:new(db)
	self.db = db
end

---@param path string
function PrintDatabase:open(path)
	print("open", path)
	self.db:open(path)
end

---@param table_name string
---@return string[]
function PrintDatabase:columns(table_name)
	return self.db:columns(table_name)
end

function PrintDatabase:close()
	print("close")
	self.db:close()
end

---@param query string
function PrintDatabase:exec(query)
	print("exec", query)
	self.db:exec(query)
end

---@param query string
---@param bind_vals table?
---@return function
function PrintDatabase:iter(query, bind_vals)
	print("iter", query, stbl.encode(bind_vals))
	return self.db:iter(query, bind_vals)
end

---@param query string
---@param bind_vals table?
---@return table
function PrintDatabase:query(query, bind_vals)
	print("query", query, stbl.encode(bind_vals))
	return self.db:query(query, bind_vals)
end

return PrintDatabase
