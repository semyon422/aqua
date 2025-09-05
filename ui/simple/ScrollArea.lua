local ui = require("ui")
local math_util = require("math_util")

---@class ui.Simple.ScrollArea.Params
---@field friction number?
---@field threshold number?
---@field max_scroll number

---@class ui.Simple.ScrollArea : ui.Drawable, ui.Simple.ScrollArea.Params
---@overload fun(params: ui.Simple.ScrollArea.Params)
local ScrollArea = ui.Drawable + {}

ScrollArea.ClassName = "ScrollArea"

local frame_aim = 60

function ScrollArea:load()
	self.handles_mouse_input = true
	self.friction = self.friction or 0.95
	self.threshold = self.threshold or 0.5
	self:resetScrollState()
end

function ScrollArea:resetScrollState()
	self.velocity = 0
	self.scroll_position = 0
	self.drag_start_y = 0
	self.drag_start_scroll_position = 0
	self.last_position = 0
	self.is_dragging = false
end

---@return number
function ScrollArea:getScrollPosition()
	return self.scroll_position
end

---@param position number
function ScrollArea:setScrollPosition(position)
	self.scroll_position = math_util.clamp(
		position,
		0,
		math.max(0, self.max_scroll - self:getHeight())
	)
end

---@param position number
function ScrollArea:scrollTo(position)
	self.target_scroll_position = math_util.clamp(
		position,
		0,
		math.max(0, self.max_scroll - self:getHeight())
	)
	self.velocity = 0
end

---@param e ui.DragStartEvent
function ScrollArea:onDragStart(e)
	self.drag_start_y = e.y
	self.drag_start_scroll_position = self.scroll_position
	self.last_position = self.scroll_position
	self.velocity = 0
	self.is_dragging = true
	self.target_scroll_position = nil
end

---@param e ui.DragEvent
function ScrollArea:onDrag(e)
	local distance = (e.y - self.drag_start_y) * self:getViewport():getViewportScale()
	local new_position = self.drag_start_scroll_position - distance
	self:setScrollPosition(new_position)
end

---@param e ui.DragEndEvent
function ScrollArea:onDragEnd(e)
	self.is_dragging = false
end

function ScrollArea:update(dt)
	dt = dt * frame_aim

	if self.is_dragging then
		local position_delta = self.scroll_position - self.last_position
		self.velocity = position_delta / dt
		self.last_position = self.scroll_position
	elseif self.target_scroll_position then
		local diff = self.target_scroll_position - self.scroll_position
		if math.abs(diff) > 0.5 then
			self.scroll_position = self.scroll_position + diff * math.min(1, dt * 0.2)
		else
			self.scroll_position = self.target_scroll_position
			self.target_scroll_position = nil
		end
	else
		self.velocity = self.velocity * math.pow(self.friction, dt)

		if math.abs(self.velocity) > 0.1 then
			local new_position = self.scroll_position + self.velocity * dt
			self:setScrollPosition(new_position)
		else
			self.velocity = 0
		end
	end
end

---@param ctx ui.TraversalContext
function ScrollArea:updateChildren(ctx)
	love.graphics.translate(0, self.scroll_position)
	ui.Drawable.updateChildren(self, ctx)
end

function ScrollArea:drawChildren()
	love.graphics.translate(0, self.scroll_position)
	ui.Drawable.drawChildren(self)
end

return ScrollArea
