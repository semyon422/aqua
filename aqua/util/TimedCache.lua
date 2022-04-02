local Class = require("aqua.util.Class")

local TimedCache = Class:new()

TimedCache.construct = function(self)
	self.objects = {}
	self.time = 0
	self.timeout = 1
end

TimedCache.loadObject = function(self, key) end

TimedCache.getObject = function(self, key)
	local time = self.time
	local objects = self.objects
	objects[key] = objects[key] or {object = self:loadObject(key)}
	objects[key].time = time
	return objects[key].object
end

TimedCache.update = function(self)
	local timeout = self.timeout
	local objects = self.objects
	local time = love.timer.getTime()
	self.time = time
	for key, obj in pairs(objects) do
		if obj.time + timeout < time then
			objects[key] = nil
		end
	end
end

return TimedCache
