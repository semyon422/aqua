local class = require("class")
local sql_util = require("rdb.sql_util")
local relations = require("rdb.relations")

---@class rdb.ModelOptions
---@field table_name string?
---@field subquery string?
---@field types table?
---@field relations {[string]: rdb.Relation}?
---@field from_db fun(row: rdb.Row)?
---@field metatable table?
---@field validate (fun(row: rdb.Row): boolean?, string?)?

---@class rdb.Model: rdb.ModelOptions
---@operator call: rdb.Model
local Model = class()

---@param opts rdb.ModelOptions
---@param models rdb.Models
function Model:new(opts, models)
	self.table_name = opts.table_name
	self.subquery = opts.subquery
	self.types = opts.types
	self.relations = opts.relations
	self.from_db = opts.from_db
	self.metatable = opts.metatable
	self.validate = opts.validate

	self.models = models
	self.orm = models._orm
end

---@generic T: rdb.Row
---@param rows T[]
---@param ... any
---@return T[]
function Model:preload(rows, ...)
	relations.preload(self, rows, ...)
	return rows
end

---@param row rdb.Row
---@return rdb.Row
function Model:row_from_db(row)
	local types = self.types
	local from_db = self.from_db
	local validate = self.validate
	local metatable = self.metatable

	row = sql_util.from_db(row, types)
	if metatable then
		setmetatable(row, metatable)
	end
	if from_db then
		from_db(row)
	end
	if validate then
		assert(validate(row))
	end

	return row
end

---@param rows rdb.Row[]
---@return rdb.Row[]
function Model:rows_from_db(rows)
	---@type rdb.Row[]
	local _rows = {}
	for i, row in ipairs(rows) do
		_rows[i] = self:row_from_db(row)
	end
	return _rows
end

---@param conditions rdb.Conditions?
---@param options rdb.Options?
---@return rdb.Row[]
function Model:select(conditions, options)
	local from = assert(self.subquery or self.table_name, "missing subquery or table name")
	conditions = sql_util.conditions_for_db(conditions, self.types)
	local rows = self.orm:select(from, conditions, options)
	return self:rows_from_db(rows)
end

---@param conditions rdb.Conditions
---@param options rdb.Options?
---@return rdb.Row?
function Model:find(conditions, options)
	options = options or {}
	options.limit = 1
	return self:select(conditions, options)[1]
end

---@param conditions rdb.Conditions?
---@param options rdb.Options?
---@return integer
function Model:count(conditions, options)
	local table_name = assert(self.table_name, "missing table name")
	conditions = sql_util.conditions_for_db(conditions, self.types)
	return tonumber(self.orm:count(table_name, conditions, options)) or 0
end

---@param values_array rdb.Row[]
---@param ignore boolean?
---@return rdb.Row[]
function Model:insert(values_array, ignore)
	local table_name = assert(self.table_name, "missing table name")
	---@type rdb.Row[]
	local new_values_array = {}
	for i, values in ipairs(values_array) do
		new_values_array[i] = sql_util.for_db(values, self.types)
	end
	local rows = self.orm:insert(table_name, new_values_array, ignore)
	return self:rows_from_db(rows)
end

---@param values rdb.Row
---@return rdb.Row
function Model:create(values)
	return self:insert({values})[1]
end

---@param values rdb.Row
---@param conditions rdb.Conditions?
---@return rdb.Row[]
function Model:update(values, conditions)
	local table_name = assert(self.table_name, "missing table name")
	conditions = sql_util.conditions_for_db(conditions, self.types)
	values = sql_util.for_db(values, self.types)
	local rows = self.orm:update(table_name, values, conditions)
	return self:rows_from_db(rows)
end

---@param conditions rdb.Conditions?
---@return rdb.Row[]
function Model:delete(conditions)
	local table_name = assert(self.table_name, "missing table name")
	conditions = sql_util.conditions_for_db(conditions, self.types)
	local rows = self.orm:delete(table_name, conditions)
	return self:rows_from_db(rows)
end

return Model
