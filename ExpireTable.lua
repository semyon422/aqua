local class = require("class")

---@class util.ExpireTable
---@operator call: util.ExpireTable
local ExpireTable = class()

ExpireTable.time = 0
ExpireTable.timeout = 1
ExpireTable.length = 0

function ExpireTable:new()
	self.data = {}
end

---@param k any
---@return any?
function ExpireTable:get(k)
	local t = self
	local time = love.timer.getTime()
	local data = t.data

	if not data[k] then
		data[k] = {t:load(k)}
	end
	data[k].time = time

	local timeout = t.timeout
	if time > t.time + timeout then
		t.time = time
		for key, obj in pairs(data) do
			if obj.time + timeout < time then
				data[key] = nil
			end
		end
	end

	return data[k][1]
end

---@param k any
---@return any?
function ExpireTable:load(k) end

return ExpireTable
