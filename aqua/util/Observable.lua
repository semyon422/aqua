local Observable = {}

Observable.new = function(self)
	local observable = {}
	observable.observers = {}
	
	setmetatable(observable, self)
	self.__index = self
	
	return observable
end

Observable.add = function(self, observer)
	self.observers[observer] = true
end

Observable.remove = function(self, observer)
	self.observers[observer] = nil
end

Observable.send = function(self, event)
	local observers = {}
	
	for observer in pairs(self.observers) do
		table.insert(observers, observer)
	end
	
	for _, observer in pairs(observers) do
		observer:receive(event)
	end
end

Observable.receive = Observable.send

return Observable