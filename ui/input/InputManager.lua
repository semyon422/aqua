local class = require("class")
local MouseDownEvent = require("ui.input.events.MouseDownEvent")
local MouseUpEvent = require("ui.input.events.MouseUpEvent")
local MouseClickEvent = require("ui.input.events.MouseClickEvent")
local ScrollEvent = require("ui.input.events.ScrollEvent")
local DragEvent = require("ui.input.events.DragEvent")
local DragStartEvent = require("ui.input.events.DragStartEvent")
local DragEndEvent = require("ui.input.events.DragEndEvent")
local FocusEvent = require("ui.input.events.FocusEvent")
local FocusLostEvent = require("ui.input.events.FocusLostEvent")
local KeyDownEvent = require("ui.input.events.KeyDownEvent")
local KeyUpEvent = require("ui.input.events.KeyUpEvent")
local TextInputEvent = require("ui.input.events.TextInputEvent")

---@class ui.Inputs
---@operator call: ui.Inputs
---@field last_mouse_up_event ui.MouseDownEvent
local Inputs = class()

---@alias ui.Inputs.Node (ui.INode | ui.IInputHandler)

local MOUSE_CLICK_MAX_DISTANCE = 30

local mouse_events = {
	mousepressed = true,
	mousereleased = true,
	mousemoved = true,
	wheelmoved = true
}

local keyboard_events = {
	keypressed = true,
	keyreleased = true,
	textinput = true
}

---@param node ui.Inputs.Node?
function Inputs:setKeyboardFocus(node)
	if self.keyboard_focus then
		local e = FocusLostEvent()
		e.target = self.keyboard_focus
		e.next_focused = node
		self:dispatchEvent(e)
	end

	if node then
		local e = FocusEvent()
		e.target = node
		e.previously_focused = self.keyboard_focus
		self:dispatchEvent(e)
	end

	self.keyboard_focus = node
end

---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@return ui.MouseEvent?
function Inputs:dispatchMouseEvent(event, traversal_ctx)
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
	self:dispatchEvent(e)
end

---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
function Inputs:dispatchKeyboardEvent(event, traversal_ctx)
	local e = nil ---@type ui.KeyboardEvent?

	if event.name == "keypressed" then
		e = KeyDownEvent()
	elseif event.name == "keyreleased" then
		e = KeyUpEvent()
	elseif event.name == "textinput" then
		e = TextInputEvent()
	else
		return
	end

	---@cast e -?
	e.key = event[1]

	if self.keyboard_focus then
		e.target = self.keyboard_focus
		self:dispatchEvent(e)
		return
	end

	for _, v in ipairs(traversal_ctx.focus_requesters) do
		e.target = v
		local handled = self:dispatchEvent(e)
		if handled then
			break
		end
		-- TODO: onKeyUp should go to the node that handled the event
		-- Maybe it's unnecessary
	end
end

---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
function Inputs:receive(event, traversal_ctx)
	if mouse_events[event.name] then
		self:dispatchMouseEvent(event, traversal_ctx)
	elseif keyboard_events[event.name] then
		self:dispatchKeyboardEvent(event, traversal_ctx)
	else
		return
	end
end

---@param e ui.UIEvent
---@return boolean? handled
function Inputs:dispatchEvent(e)
	-- TODO: who cares about capture phase
	-- create your own InputManager if you need it

	local handled = false ---@type boolean?
	e.current_target = e.target
	while e.current_target do
		handled = handled or e:trigger()
		if e.stop then
			return
		end
		e.current_target = e.current_target.parent
	end

	return handled
end

return Inputs
