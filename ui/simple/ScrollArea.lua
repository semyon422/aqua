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

function ScrollArea:load()
	self.stiffness = self.stiffness or 0.3
	self.damping = self.damping or 0.5
	self.threshold = self.threshold or 0.5
	self.distance = 40
	self.velocity = 0
	self.target_y = 0
	self.position = 0
	self.accepts_input = true
	self.content_size = 0

	self.origin_scroll_position = 0
	self.origin_drag_position = 0
	self.drag = false
end

---@param y number
function ScrollArea:setTargetY(y)
	self.target_y = y
end

---@param e ui.ScrollEvent
function ScrollArea:onScroll(e)
	self.target_y = self.target_y + e.direction_y * -40
end

function ScrollArea:invalidateLayout()
	local _, h = self:getContentSize()
	self.content_size = h
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

---@param e ui.DragStartEvent
function ScrollArea:onDragStart(e)
	self.origin_scroll_position = self.position
	self.origin_drag_position = e.y
	self.velocity = 0
	self.drag = true
end

---@param e ui.DragStartEvent
function ScrollArea:onDragEnd(e)
	self.drag = false
end

---@param e ui.DragEvent
function ScrollArea:onDrag(e)
	self.velocity = 0

	local _, distance = self.transform:transformPoint(0, e.y - self.origin_drag_position)
	self.position = self.origin_scroll_position + distance
end

local frame_aim = 60

function ScrollArea:update(dt)
	if self.drag then
		return
	end

	local position = self.position
	local displacement = self.target_y - position
	local acceleration = displacement * self.stiffness
	dt = dt * frame_aim

	self.velocity = self.velocity + acceleration * dt
	self.velocity = self.velocity * math.pow(self.damping, dt)
	position = position + self.velocity * dt

	local max_scroll = self.max_scroll - self.content_size
	if self.target_y < 0 or self.target_y > max_scroll then
		self.target_y = math_util.clamp(self.target_y, 0, max_scroll)
	end

	if math.abs(displacement) > self.threshold or math.abs(self.velocity) > 0.1 then
		self.position = position
	end
end

return ScrollArea
