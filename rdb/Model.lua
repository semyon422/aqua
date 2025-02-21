local class = require("class")
local sql_util = require("rdb.sql_util")
local relations = require("rdb.relations")

---@alias rdb.ModelOptions {table_name: string, types: table, relations: {[string]: rdb.Relation}, from_db: function?, metatable: table?}

---@class rdb.Model
---@operator call: rdb.Model
local Model = class()

---@param opts rdb.ModelOptions
---@param models rdb.Models
function Model:new(opts, models)
	self.table_name = opts.table_name
	self.types = opts.types or {}
	self.relations = opts.relations or {}
	self.from_db = opts.from_db
	self.metatable = opts.metatable
	self.models = models
	self.orm = models._orm
end

function Model:preload(rows, ...)
	relations.preload(self, rows, ...)
end

---@param rows rdb.Row[]
---@return rdb.Row[]
function Model:rows_from_db(rows)
	local from_db = self.from_db
	local metatable = self.metatable
	---@type rdb.Row[]
	local _rows = {}
	for i, row in ipairs(rows) do
		row = sql_util.from_db(row, self.types)
		if metatable then
			setmetatable(row, metatable)
		end
		if from_db then
			from_db(row)
		end
		_rows[i] = row
	end
	return _rows
end

---@param conditions table?
---@param options table?
---@return rdb.Row[]
function Model:select(conditions, options)
	conditions = sql_util.conditions_for_db(conditions, self.types)
	local rows = self.orm:select(self.table_name, conditions, options)
	return self:rows_from_db(rows)
end

---@param conditions table
---@return rdb.Row?
function Model:find(conditions)
	return self:select(conditions, {limit = 1})[1]
end

---@param conditions table?
---@param options table?
---@return integer
function Model:count(conditions, options)
	conditions = sql_util.conditions_for_db(conditions, self.types)
	return tonumber(self.orm:count(self.table_name, conditions, options)) or 0
end

---@param values_array rdb.Row[]
---@param ignore boolean?
---@return rdb.Row[]
function Model:insert(values_array, ignore)
	---@type rdb.Row[]
	local new_values_array = {}
	for i, values in ipairs(values_array) do
		new_values_array[i] = sql_util.for_db(values, self.types)
	end
	local rows = self.orm:insert(self.table_name, new_values_array, ignore)
	return self:rows_from_db(rows)
end

---@param values table
---@return rdb.Row
function Model:create(values)
	return self:insert({values})[1]
end

---@param values table
---@param conditions table?
---@return rdb.Row[]
function Model:update(values, conditions)
	conditions = sql_util.conditions_for_db(conditions, self.types)
	values = sql_util.for_db(values, self.types)
	local rows = self.orm:update(self.table_name, values, conditions)
	return self:rows_from_db(rows)
end

---@param conditions table?
---@return rdb.Row[]
function Model:delete(conditions)
	conditions = sql_util.conditions_for_db(conditions, self.types)
	local rows = self.orm:delete(self.table_name, conditions)
	return self:rows_from_db(rows)
end

return Model
