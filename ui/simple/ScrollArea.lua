local ui = require("ui")
local math_util = require("math_util")

---@class ui.Simple.ScrollArea.Params
---@field stiffness number?
---@field damping number?
---@field threshold number?
---@field distance number?
---@field max_scroll number

---@class ui.Simple.ScrollArea : ui.Drawable, ui.Simple.ScrollArea.Params
---@overload fun(params: ui.Simple.ScrollArea.Params
local ScrollArea = ui.Drawable + {}

local initial_stiffiness = 0.5
local initial_damping = 0.15

function ScrollArea:load()
	self.stiffness = initial_stiffiness
	self.damping = initial_damping
	self.threshold = 0.5
	self.distance = 140
	self.velocity = 0
	self.target_y = 0
	self.position = 0
	self.accepts_input = true

	self.origin_scroll_position = 0
	self.origin_drag_position = 0
	self.drag = false
end

---@param y number
function ScrollArea:scrollTo(y)
	self.stiffness = initial_stiffiness
	self.damping = initial_damping
	self:setTargetY(y)
end

---@return number
function ScrollArea:getScrollPosition()
	return self.position
end

---@param position number
---@private
function ScrollArea:setScrollPosition(position)
	self.position = math_util.clamp(position, 0, self.max_scroll)
end

---@param y number
---@private
function ScrollArea:setTargetY(y)
	self.target_y = math_util.clamp(y, 0, self.max_scroll)
end

---@param e ui.ScrollEvent
function ScrollArea:onScroll(e)
	self:setTargetY(self.position + e.direction_y * -self.distance)
	self.stiffness = initial_stiffiness
	self.damping = initial_damping
end

---@param e ui.DragStartEvent
function ScrollArea:onDragStart(e)
	self.origin_scroll_position = self.position
	self.origin_drag_position = e.y
	self.stiffness = 0
	self.damping = 0.9
	self.drag = true
end

---@param e ui.DragStartEvent
function ScrollArea:onDragEnd(e)
	self.drag = false
end

---@param e ui.DragEvent
function ScrollArea:onDrag(e)
	local distance = (e.y - self.origin_drag_position) * (768 / love.graphics.getHeight())
	self:setScrollPosition(self.origin_scroll_position - distance)
	self:setTargetY(self.position)
end

local frame_aim = 60

function ScrollArea:update(dt)
	dt = dt * frame_aim

	if self.drag then
		local dp = self.position - (self.last_drag_position or self.position)
		self.velocity = dp / dt
		self.last_drag_position = self.position
		return
	end

	local position = self.position
	local displacement = self.target_y - position
	local acceleration = displacement * self.stiffness

	self.velocity = self.velocity + acceleration * dt
	self.velocity = self.velocity * math.pow(self.damping, dt)
	position = position + self.velocity * dt

	if math.abs(displacement) > self.threshold or math.abs(self.velocity) > 0.1 then
		self:setScrollPosition(position)
	end
end

---@param ctx ui.TraversalContext
function ScrollArea:updateChildren(ctx)
	love.graphics.translate(0, self.position)
	ui.Drawable.updateChildren(self, ctx)
end

function ScrollArea:drawChildren()
	love.graphics.translate(0, self.position)
	ui.Drawable.drawChildren(self)
end

return ScrollArea
