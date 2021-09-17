local Class = require("aqua.util.Class")

local Animation = Class:new()

function Animation:update(dt)
	local range = self.range
	self.time = self.time + dt

	local c = math.floor(self.time * self.rate)
	local frames = (range[2] - range[1] + 1)
	if c >= 0 and c < self.cycles * frames then
		self.frame = range[1] + c % frames
	else
		self.frame = nil
	end
end

return Animation
