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
---@field last_mouse_down_event ui.MouseDownEvent
local Inputs = class()

Inputs.MOUSE_CLICK_MAX_DISTANCE = 30

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

---@param node ui.Node?
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

---@private
---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers? {control?: boolean, shift?: boolean, alt?: boolean, super?: boolean}
---@return ui.MouseDownEvent
function Inputs:handleMouseDown(event, traversal_ctx, modifiers)
	local e = MouseDownEvent(modifiers)
	e.button = event[3]
	self.last_mouse_down_event = e
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers? {control?: boolean, shift?: boolean, alt?: boolean, super?: boolean}
---@return ui.MouseUpEvent?
function Inputs:handleMouseUp(event, traversal_ctx, modifiers)
	if not self.last_mouse_down_event then
		return
	end

	local dx = (self.last_mouse_down_event.x - traversal_ctx.mouse_x)
	local dy = (self.last_mouse_down_event.y - traversal_ctx.mouse_y)
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance < self.MOUSE_CLICK_MAX_DISTANCE then
		local ce = MouseClickEvent(modifiers)
		ce.target = self.last_mouse_down_event.target
		ce.x = traversal_ctx.mouse_x
		ce.y = traversal_ctx.mouse_y
		ce.button = event[3]
		self:dispatchEvent(ce)
	end

	if self.last_drag_event then
		local de = DragEndEvent(modifiers)
		de.target = self.last_drag_event.target
		de.x = traversal_ctx.mouse_x
		de.y = traversal_ctx.mouse_y
		self:dispatchEvent(de)
		self.last_drag_event = nil
	end

	local e = MouseUpEvent(traversal_ctx.mouse_target)
	e.button = event[3]
	self.last_mouse_down_event = nil
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers? {control?: boolean, shift?: boolean, alt?: boolean, super?: boolean}
---@return ui.ScrollEvent
function Inputs:handleWheel(event, traversal_ctx, modifiers)
	local e = ScrollEvent(modifiers)
	e.direction_x = event[1]
	e.direction_y = event[2]
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers? {control?: boolean, shift?: boolean, alt?: boolean, super?: boolean}
---@return ui.MouseEvent?
function Inputs:handleMouseMove(event, traversal_ctx, modifiers)
	if not self.last_mouse_down_event then
		return
	end

	---@type ui.MouseEvent
	local e
	if not self.last_drag_event then
		e = DragStartEvent(modifiers)
		self.last_drag_event = e
	else
		e = DragEvent(modifiers)
		e.target = self.last_drag_event.target
	end
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers? {control?: boolean, shift?: boolean, alt?: boolean, super?: boolean}
---@return ui.MouseEvent?
function Inputs:dispatchMouseEvent(event, traversal_ctx, modifiers)
	local e = nil ---@type ui.MouseEvent?

	if event.name == "mousepressed" then
		e = self:handleMouseDown(event, traversal_ctx, modifiers)
	elseif event.name == "mousereleased" then
		e = self:handleMouseUp(event, traversal_ctx, modifiers)
	elseif event.name == "wheelmoved" then
		e = self:handleWheel(event, traversal_ctx, modifiers)
	elseif event.name == "mousemoved" then
		e = self:handleMouseMove(event, traversal_ctx, modifiers)
	end

	if not e then
		return
	end

	e.target = e.target or traversal_ctx.mouse_target
	e.x = traversal_ctx.mouse_x
	e.y = traversal_ctx.mouse_y
	self:dispatchEvent(e)
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers? {control?: boolean, shift?: boolean, alt?: boolean, super?: boolean}
function Inputs:dispatchKeyboardEvent(event, traversal_ctx, modifiers)
	local e = nil ---@type ui.KeyboardEvent?

	if event.name == "keypressed" then
		e = KeyDownEvent(modifiers)
	elseif event.name == "keyreleased" then
		e = KeyUpEvent(modifiers)
	elseif event.name == "textinput" then
		e = TextInputEvent(modifiers)
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
	end
end

---@param event {name: string, [integer]: any}
---@param traversal_ctx ui.TraversalContext
---@param modifiers {control: boolean, shift: boolean, alt: boolean, super: boolean}
function Inputs:receive(event, traversal_ctx, modifiers)
	if mouse_events[event.name] then
		self:dispatchMouseEvent(event, traversal_ctx, modifiers)
	elseif keyboard_events[event.name] then
		self:dispatchKeyboardEvent(event, traversal_ctx, modifiers)
	else
		return
	end
end

---@param e ui.UIEvent
---@return boolean? handled
function Inputs:dispatchEvent(e)
	local handled = false ---@type boolean?
	e.current_target = e.target
	while e.current_target do
		handled = handled or e:trigger()
		if e.stop then
			return
		end
		local parent = e.current_target.parent
		e.current_target = parent
	end

	return handled
end

return Inputs
