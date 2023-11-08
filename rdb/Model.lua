local class = require("class")
local sql_util = require("rdb.sql_util")
local ModelRow = require("rdb.ModelRow")

---@class rdb.Model
---@operator call: rdb.Model
local Model = class()

---@param opts table
---@param models rdb.Models
function Model:new(opts, models)
	self.table_name = opts.table_name
	self.types = opts.types
	self.relations = opts.relations
	self.models = models
	self.orm = models._orm

	local base_row = {
		__model = self,
		__models = models,
		__orm = models._orm,
	}
	setmetatable(base_row, {__index = ModelRow})
	self.row_mt = {__index = base_row}
end

---@param conditions table?
---@return rdb.ModelRow[]
function Model:select(conditions)
	local rows = self.orm:select(self.table_name, conditions)
	for i, row in ipairs(rows) do
		rows[i] = setmetatable(sql_util.from_db(row, self.types), self.row_mt)
	end
	return rows
end

---@param conditions table
---@return rdb.ModelRow?
function Model:find(conditions)
	return self:select(conditions)[1]
end

---@param values_array table
---@param ignore boolean?
---@return rdb.ModelRow[]
function Model:insert(values_array, ignore)
	local new_values_array = {}
	for i, values in ipairs(values_array) do
		new_values_array[i] = sql_util.for_db(values, self.types)
	end
	local rows = self.orm:insert(self.table_name, new_values_array, ignore)
	for i, row in ipairs(rows) do
		rows[i] = setmetatable(sql_util.from_db(row, self.types), self.row_mt)
	end
	return rows
end

---@param values table
---@param ignore boolean?
---@return rdb.ModelRow?
function Model:create(values, ignore)
	return self:insert({values}, ignore)[1]
end

---@param values table
---@param conditions table?
function Model:update(values, conditions)
	self.orm:update(self.table_name, sql_util.for_db(values, self.types), conditions)
end

---@param conditions table?
function Model:delete(conditions)
	self.orm:delete(self.table_name, conditions)
end

return Model
