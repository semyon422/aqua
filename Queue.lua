local Queue = {}

Queue.new = function()
	local self = {}

	self.events = {}
	self.count = 0

	return setmetatable(self, {
		__index = Queue,
		__call = coroutine.wrap(function()
			while true do
				while self.count > 0 do
					coroutine.yield(self:remove())
				end
				coroutine.yield()
			end
		end)
	})
end

function Queue:add(event)
	self.count = self.count + 1
	self.events[self.count] = event
end

function Queue:remove()
	local events = self.events
	local count = self.count
	local event = events[count]
	events[count] = nil
	self.count = count - 1
	return event
end

return Queue
