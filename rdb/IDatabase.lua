local class = require("class")

---@class rdb.IDatabase
---@operator call: rdb.IDatabase
local IDatabase = class()

---@param db string
function IDatabase:open(db) end

function IDatabase:close() end

---@param query string
function IDatabase:exec(query) end

---@param query string
---@param bind_vals table?
---@return table
function IDatabase:query(query, bind_vals)
	return {}
end

return IDatabase
