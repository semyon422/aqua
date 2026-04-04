local test = {}

local function make_transform()
	return {
		setTransformation = function(self, x, y, r, sx, sy, ox, oy)
			self.x = x or 0
			self.y = y or 0
			self.sx = sx or 1
			self.sy = sy or 1
			return self
		end,
		reset = function(self)
			self.x = 0
			self.y = 0
			self.sx = 1
			self.sy = 1
			return self
		end,
		apply = function(self, other)
			self.x = self.x + (other.x or 0) * self.sx
			self.y = self.y + (other.y or 0) * self.sy
			self.sx = self.sx * (other.sx or 1)
			self.sy = self.sy * (other.sy or 1)
			return self
		end,
		inverseTransformPoint = function(self, x, y)
			return (x - self.x) / self.sx, (y - self.y) / self.sy
		end,
	}
end

_G.love = _G.love or {}
love.math = love.math or {}
love.math.newTransform = love.math.newTransform or make_transform
love.timer = love.timer or {}
love.timer.getTime = love.timer.getTime or function()
	return 0
end

local View = require("ui.View")

local CustomValueView = View + {}

function CustomValueView:update(dt)
	self:getAnimationValue("pulse", {
		speed = 20,
	}):set(1)
end

---@param t testing.T
function test.tick_updates_interaction_values(t)
	local view = View()
	local hover = view:getAnimationValue("hover", {speed = 10})
	local focus = view:getAnimationValue("focus", {speed = 10})
	local pressed = view:getAnimationValue("pressed", {speed = 10})

	view.mouse_over = true
	view.focused = true
	view.pressed = true
	view:tick(0.1)

	t:assert(hover:get() > 0)
	t:assert(focus:get() > 0)
	t:assert(pressed:get() > 0)

	view.mouse_over = false
	view.focused = false
	view.pressed = false
	view:tick(1)

	t:eq(hover:get(), 0)
	t:eq(focus:get(), 0)
	t:eq(pressed:get(), 0)
end

---@param t testing.T
function test.tick_updates_custom_values_after_view_update(t)
	local view = CustomValueView()
	local pulse = view:getAnimationValue("pulse", {
		speed = 20,
	})

	view:tick(0.1)

	t:assert(pulse:get() > 0)
	t:eq(pulse.target, 1)
end

return test
