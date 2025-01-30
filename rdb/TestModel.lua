local class = require("class")
local table_util = require("table_util")

---@alias rdb.FakeRow {[string]: any}

---@class rdb.TestModel
---@operator call: rdb.TestModel
---@field [integer] rdb.FakeRow
local TestModel = class()

---@param tbl rdb.FakeRow[]
---@param conditions rdb.FakeRow?
---@param from_end boolean?
---@return fun(): integer, rdb.FakeRow
local function find(tbl, conditions, from_end)
	conditions = conditions or {}
	return coroutine.wrap(function()
		local a, b, c = 1, #tbl, 1
		if from_end then
			a, b, c = #tbl, 1, -1
		end
		for i = a, b, c do
			local row = tbl[i]
			local eq = true
			for k, v in pairs(conditions) do
				eq = eq and row[k] == v
			end
			if eq then
				coroutine.yield(i, row)
			end
		end
	end)
end

---@param tbl rdb.FakeRow[]
---@return integer
local function get_next_id(tbl)
	if #tbl == 0 then
		return 1
	end
	return tbl[#tbl].id + 1
end

---@param conditions rdb.FakeRow?
---@return rdb.FakeRow[]
function TestModel:select(conditions)
	local rows = {}
	for i, row in find(self, conditions) do
		table.insert(rows, row)
	end
	return rows
end

---@param conditions rdb.FakeRow
---@return rdb.FakeRow?
function TestModel:find(conditions)
	local i, row = find(self, conditions)()
	return row
end

---@param conditions rdb.FakeRow?
---@return integer
function TestModel:count(conditions)
	return #self:select(conditions)
end

---@param values rdb.FakeRow
---@return rdb.FakeRow
function TestModel:create(values)
	local row = table_util.copy(values)
	---@cast row rdb.FakeRow
	row.id = get_next_id(self)
	table.insert(self, row)
	return row
end

---@param conditions rdb.FakeRow
---@return rdb.FakeRow[]
function TestModel:remove(conditions)
	local rows = {}
	for i, row in find(self, conditions, true) do
		table.insert(rows, row)
		table.remove(self, i)
	end
	return rows
end

---@param values rdb.FakeRow
---@param conditions rdb.FakeRow
---@return rdb.FakeRow[]
function TestModel:update(values, conditions)
	local rows = {}
	for i, row in find(self, conditions) do
		table.insert(rows, row)
		table_util.copy(values, row)
	end
	return rows
end

return TestModel
