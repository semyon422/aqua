local class = require("class")

local Observable = class()

function Observable:add(observer)
	for i, o in ipairs(self) do
		if o == observer then
			return
		end
	end
	table.insert(self, observer)
end

function Observable:remove(observer)
	for i, o in ipairs(self) do
		if o == observer then
			return table.remove(self, i)
		end
	end
end

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
