local Container = {}

Container.new = function(self)
	local container = {}
	container.objects = {}
	container.objectList = {}
	container.needSort = false
	
	setmetatable(container, self)
	self.__index = self
	
	return container
end

Container.add = function(self, sprite)
	self.objects[sprite] = true
	self.needSort = true
end

Container.sort = function(self)
	if not self.needSort then
		return
	end
	
	local objects = {}
	for object in pairs(self.objects) do
		objects[#objects + 1] = object
	end
	
	table.sort(objects, function(a, b)
		return a.layer < b.layer
	end)
	
	self.objectList = objects
	
	self.needSort = false
end

Container.update = function(self)
	self:sort()
	
	local objectList = self.objectList
	for i = 1, #objectList do
		objectList[i]:update()
	end
end

Container.draw = function(self)
	local objectList = self.objectList
	for i = 1, #objectList do
		objectList[i]:draw()
	end
end

return Container