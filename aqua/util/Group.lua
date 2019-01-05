local Class = require("aqua.util.Class")

local Group = Class:new()

Group.construct = function(self)
	self.objects = {}
end

Group.add = function(self, object)
	self.objects[object] = true
end

Group.remove = function(self, object)
	self.objects[object] = nil
end

Group.call = function(self, func)
	for object in pairs(self.objects) do
		func(object)
	end
end

return Group
