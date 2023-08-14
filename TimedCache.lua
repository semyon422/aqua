local class = require("class")

local TimedCache = class()

function TimedCache:new()
	self.objects = {}
	self.time = 0
	self.timeout = 1
end

function TimedCache:loadObject(key) end

function TimedCache:getObject(key)
	local time = self.time
	local objects = self.objects
	objects[key] = objects[key] or {object = self:loadObject(key)}
	objects[key].time = time
	return objects[key].object
end

function TimedCache:update()
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
