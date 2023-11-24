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

---@param rows table
---@return rdb.ModelRow[]
function Model:rows_from_db(rows)
	local _rows = {}
	for i, row in ipairs(rows) do
		_rows[i] = setmetatable(sql_util.from_db(row, self.types), self.row_mt)
	end
	return _rows
end

---@param conditions table?
---@param options table?
---@return rdb.ModelRow[]
function Model:select(conditions, options)
	conditions = sql_util.for_db(conditions, self.types)
	local rows = self.orm:select(self.table_name, conditions, options)
	for i, row in ipairs(rows) do
		row = sql_util.from_db(row, self.types)
		rows[i] = setmetatable(row, self.row_mt)
	end
	return rows
end

---@param conditions table
---@return rdb.ModelRow?
function Model:find(conditions)
	return self:select(conditions)[1]
end

---@param conditions table?
---@return number
function Model:count(conditions)
	conditions = sql_util.for_db(conditions, self.types)
	return self.orm:count(self.table_name, conditions)
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
	return self:rows_from_db(rows)
end

---@param values table
---@param ignore boolean?
---@return rdb.ModelRow?
function Model:create(values, ignore)
	return self:insert({values}, ignore)[1]
end

---@param values table
---@param conditions table?
---@return rdb.ModelRow[]
function Model:update(values, conditions)
	conditions = sql_util.for_db(conditions, self.types)
	values = sql_util.for_db(values, self.types)
	local rows = self.orm:update(self.table_name, values, conditions)
	return self:rows_from_db(rows)
end

---@param conditions table?
---@return rdb.ModelRow[]
function Model:delete(conditions)
	conditions = sql_util.for_db(conditions, self.types)
	local rows = self.orm:delete(self.table_name, conditions)
	return self:rows_from_db(rows)
end

return Model
