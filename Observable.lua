local class = require("class")

---@class util.Observable
---@operator call: util.Observable
local Observable = class()

---@param observer any
function Observable:add(observer)
	for i, o in ipairs(self) do
		if o == observer then
			return
		end
	end
	table.insert(self, observer)
end

---@param observer any
---@return any
function Observable:remove(observer)
	for i, o in ipairs(self) do
		if o == observer then
			return table.remove(self, i)
		end
	end
end

---@param event table
function Observable:send(event)
	self.temp = self.temp or {}
	local observers = self.temp

	for i, o in ipairs(self) do
		observers[i] = o
	end

	for i = 1, #self do
		observers[i]:receive(event)
	end
end

Observable.receive = Observable.send

return Observable
