local Class = require("aqua.util.Class")

local Animation = Class:new()

function Animation:update(dt)
	local range = self.range
	self.time = self.time + dt

	local c = math.floor(self.time * self.rate)
	local frames = math.abs(range[2] - range[1]) + 1
	if c >= 0 and c < self.cycles * frames then
		if frames == 1 then
			self.frame = range[1]
		else
			self.frame = c % frames * (range[2] - range[1]) / (frames - 1) + range[1]
		end
	else
		self.frame = nil
	end
end

return Animation
