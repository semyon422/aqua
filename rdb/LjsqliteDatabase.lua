local sqlite = require("ljsqlite3")
local IDatabase = require("rdb.IDatabase")

---@class rdb.LjsqliteDatabase: rdb.IDatabase
---@operator call: rdb.LjsqliteDatabase
local LjsqliteDatabase = IDatabase + {}

---@param db string
function LjsqliteDatabase:open(db)
	self.c = sqlite.open(db)
end

function LjsqliteDatabase:close()
	self.c:close()
end

---@param query string
function LjsqliteDatabase:exec(query)
	self.c:exec(query)
end

---@param row table
---@param colnames table
---@return table
local function to_object(row, colnames)
	local t = {}
	for i, k in ipairs(colnames) do
		t[k] = row[i]
	end
	return t
end

---@param query string
---@return table?
function LjsqliteDatabase:query(query)
	print(query)
	local stmt = self.c:prepare(query)

	local colnames = {}
	local row = stmt:step({}, colnames)
	if not row then
		stmt:close()
		return
	end

	local objects = {}
	while row do
		objects[#objects + 1] = to_object(row, colnames)
		row = stmt:step(row)
	end

	stmt:close()
	return objects
end

return LjsqliteDatabase
