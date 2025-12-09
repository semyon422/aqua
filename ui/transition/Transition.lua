local ITransition = require("ui.transition.ITransition")
require("table.clear")

---@class ui.Transition : ui.ITransition
---@operator call: ui.Transition
local Transition = ITransition + {}

---@param target_value number | table
---@param ease fun(t: number): number
---@param duration number
---@param get_value fun(): number | table
---@param set_value fun(v: number | table)
function Transition:new(target_value, ease, duration, get_value, set_value)
	self.target_value = target_value
	self.ease = ease
	self.duration = duration
	self.current_time = 0
	self.completed = false
	self.get_value = get_value
	self.set_value = set_value
end

function Transition:start()
	self.start_value = self.get_value()
	self.current_time = 0
	self.is_completed = false
end

---@param dt number
function Transition:update(dt)
	self.current_time = self.current_time + dt

	if self.current_time >= self.duration then
		self.current_time = self.duration
		self:markCompleted()
	end

	self:interpolate()
end

function Transition:markCompleted()
	self.is_completed = true
end

local temp_table = {}

function Transition:interpolate()
	local t = self.ease(self.current_time / self.duration)
	local from = self.start_value
	local to = self.target_value

	if type(to) == "number" then
		self.set_value(from + (to - from) * t)
	else -- table
		table.clear(temp_table)
		---@cast from -number
		for k, v in pairs(from) do
			temp_table[k] = v + (to[k] - v) * t
		end
		self.set_value(temp_table)
	end
end

return Transition
