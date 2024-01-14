local sqlite = require("ljsqlite3")
local IDatabase = require("rdb.IDatabase")
local sql_util = require("rdb.sql_util")

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
---@param bind_vals table?
---@return table
function LjsqliteDatabase:query(query, bind_vals)
	local stmt = self.c:prepare(query)
	if bind_vals then
		for i, v in ipairs(bind_vals) do
			if v == sql_util.NULL then
				v = nil
			end
			stmt:bind1(i, v)
		end
	end

	local objects = {}

	local colnames = {}
	local row = stmt:step({}, colnames)
	if not row then
		stmt:close()
		return objects
	end

	while row do
		objects[#objects + 1] = to_object(row, colnames)
		row = stmt:step(row)
	end

	stmt:close()
	return objects
end

return LjsqliteDatabase
