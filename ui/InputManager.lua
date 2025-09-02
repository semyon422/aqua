local class = require("class")
local MouseDownEvent = require("ui.input_events.MouseDownEvent")
local MouseUpEvent = require("ui.input_events.MouseUpEvent")
local MouseClickEvent = require("ui.input_events.MouseClickEvent")
local ScrollEvent = require("ui.input_events.ScrollEvent")
local DragEvent = require("ui.input_events.DragEvent")
local DragStartEvent = require("ui.input_events.DragStartEvent")
local DragEndEvent = require("ui.input_events.DragEndEvent")

---@class ui.InputManager
---@operator call: ui.InputManager
---@field last_mouse_up_event ui.MouseDownEvent
local InputManager = class()

local MOUSE_CLICK_MAX_DISTANCE = 30

local mouse_events = {
	mousepressed = true,
	mousereleased = true,
	mousemoved = true,
	wheelmoved = true
}

---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@return ui.MouseEvent?
function InputManager:createMouseEvent(event, traversal_ctx)
	local e = nil ---@type ui.MouseEvent

	if event.name == "mousepressed" then
		e = MouseDownEvent()
		e.button = event[3]
		self.last_mouse_down_event = e
	elseif event.name == "mousereleased" then
		if not self.last_mouse_down_event then
			return
		end

		local dx = (self.last_mouse_down_event.x - traversal_ctx.mouse_x)
		local dy = (self.last_mouse_down_event.y - traversal_ctx.mouse_y)
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance < MOUSE_CLICK_MAX_DISTANCE then
			-- TODO: don't dispatch here
			local ce = MouseClickEvent()
			ce.target = self.last_mouse_down_event.target
			ce.x = traversal_ctx.mouse_x
			ce.y = traversal_ctx.mouse_y
			ce.button = event[3]
			self:dispatchEvent(ce)
		end

		if self.last_drag_event then
			-- TODO: don't dispatch here
			local de = DragEndEvent()
			de.target = self.last_drag_event.target
			de.x = traversal_ctx.mouse_x
			de.y = traversal_ctx.mouse_y
			self:dispatchEvent(de)
			self.last_drag_event = nil
		end

		e = MouseUpEvent(traversal_ctx.mouse_target)
		e.button = event[3]
		self.last_mouse_down_event = nil
	elseif event.name == "wheelmoved" then
		e = ScrollEvent()
		e.direction_x = event[1]
		e.direction_y = event[2]
	elseif event.name == "mousemoved" and self.last_mouse_down_event then
		if not self.last_drag_event then
			e = DragStartEvent()
			self.last_drag_event = e
		else
			e = DragEvent()
			e.target = self.last_drag_event.target
		end
	else
		return
	end

	e.target = e.target or traversal_ctx.mouse_target
	e.x = traversal_ctx.mouse_x
	e.y = traversal_ctx.mouse_y
	return e
end

---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
function InputManager:receive(event, traversal_ctx)
	local e = nil ---@type ui.UIEvent

	if mouse_events[event.name] then
		e = self:createMouseEvent(event, traversal_ctx)
	else
		return
	end

	if e then
		self:dispatchEvent(e)
	end
end

---@param e ui.InputEvent
---@private
function InputManager:dispatchEvent(e)
	-- TODO: capture phase

	local current_target = e.target
	while current_target do
		local f = current_target[e.callback_name]
		if f then
			f(current_target, e)
		end
		if e.stop then
			return
		end
		current_target = current_target.parent
	end
end

return InputManager
