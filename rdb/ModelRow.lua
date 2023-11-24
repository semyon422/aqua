local table_util = require("table_util")

---@class rdb.ModelRow
---@field __model rdb.Model
---@field [string] any
local ModelRow = {}

function ModelRow:select()
	local row = self.__model:select({id = self.id})[1]
	table_util.clear(self)
	table_util.copy(row, self)
end

---@param values table
function ModelRow:update(values)
	local row = self.__model:update(values, {id = self.id})[1]
	table_util.clear(self)
	table_util.copy(row, self)
end

---@return boolean
function ModelRow:delete()
	return self.__model:delete({id = self.id})[1] ~= nil
end

return ModelRow
