local class = require("class")

---@class rdb.IDatabase
---@operator call: rdb.IDatabase
local IDatabase = class()

---@param query string
function IDatabase:exec(query) end

---@param query string
---@param bind_vals table?
---@return fun(): integer?, rdb.Row?
function IDatabase:iter(query, bind_vals)
	return function() end
end

---@param query string
---@param bind_vals table?
---@return table
function IDatabase:query(query, bind_vals)
	return {}
end

---@param table_name string
---@return string[]
function IDatabase:columns(table_name)
	return {}
end

---@param query string
---@param bind_vals any[]?
---@return rdb.Row[]
function IDatabase:query(query, bind_vals)
	---@type rdb.Row[]
	local objects = {}
	for i, obj in self:iter(query, bind_vals) do
		objects[i] = obj
	end
	return objects
end

return IDatabase
