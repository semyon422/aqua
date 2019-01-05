local Observable = {}

Observable.new = function(self)
	local observable = {}
	observable.observers = {}
	
	setmetatable(observable, self)
	self.__index = self
	
	return observable
end

Observable.addObserver = function(self, observer)
	self.observers[observer] = true
end

Observable.removeObserver = function(self, observer)
	self.observers[observer] = nil
end

Observable.sendEvent = function(self, event)
	local observers = {}
	
	for observer in pairs(self.observers) do
		table.insert(observers, observer)
	end
	
	for _, observer in pairs(observers) do
		observer:receiveEvent(event)
	end
end

Observable.receiveEvent = Observable.sendEvent

return Observable