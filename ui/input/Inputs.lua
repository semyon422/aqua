local class = require("class")
local table_util = require("table_util")
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
local HoverEvent = require("ui.input.events.HoverEvent")
local HoverLostEvent = require("ui.input.events.HoverLostEvent")

---@class ui.ModifierKeys
---@field control boolean
---@field shift boolean
---@field alt boolean
---@field super boolean

---@class ui.Inputs
---@operator call: ui.Inputs
---@field mouse_x number 
---@field mouse_y number
---@field mouse_target ui.Node?
---@field focus_requesters ui.Node[]
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

---@type ui.ModifierKeys
local default_modifiers = {control = false, shift = false, alt = false, super = false}

function Inputs:new()
	self.mouse_x = -math.huge
	self.mouse_y = -math.huge
	self.mouse_target = nil
	self.focus_requesters = {}
end

---@param mouse_x number Global Mouse X position
---@param mouse_y number Global Mouse Y position
function Inputs:beginFrame(mouse_x, mouse_y)
	self.mouse_x = mouse_x
	self.mouse_y = mouse_y
	self.mouse_target = nil
	table_util.clear(self.focus_requesters)
end

---@param node ui.Node
function Inputs:processNode(node)
	if node.handles_mouse_input or node.handles_keyboard_input then
		if node.handles_keyboard_input then
			table.insert(self.focus_requesters, node)
		end

		if not self.mouse_target and node.handles_mouse_input then
			local had_focus = node.mouse_over
			node.mouse_over = node:isMouseOver(self.mouse_x, self.mouse_y)

			if node.mouse_over then
				self.mouse_target = node
			end

			if not had_focus and node.mouse_over then
				local e = HoverEvent(default_modifiers)
				e.target = node
				self:dispatchEvent(e)
			elseif had_focus and not node.mouse_over then
				local e = HoverLostEvent(default_modifiers)
				e.target = node
				self:dispatchEvent(e)
			end
		else
			if node.mouse_over then
				node.mouse_over = false

				local e = HoverLostEvent(default_modifiers)
				e.target = node
				self:dispatchEvent(e)
			end
		end
	end
end

---@param node ui.Node?
---@param modifiers ui.ModifierKeys
function Inputs:setKeyboardFocus(node, modifiers)
	if self.keyboard_focus then
		local e = FocusLostEvent(modifiers)
		e.target = self.keyboard_focus
		e.next_focused = node
		self:dispatchEvent(e)
	end

	if node then
		local e = FocusEvent(modifiers)
		e.target = node
		e.previously_focused = self.keyboard_focus
		self:dispatchEvent(e)
	end

	self.keyboard_focus = node
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers ui.ModifierKeys
---@return ui.MouseDownEvent
function Inputs:handleMouseDown(event, modifiers)
	local e = MouseDownEvent(modifiers)
	e.button = event[3]
	self.last_mouse_down_event = e
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers ui.ModifierKeys
---@return ui.MouseUpEvent?
function Inputs:handleMouseUp(event, modifiers)
	if not self.last_mouse_down_event then
		return
	end

	local dx = (self.last_mouse_down_event.x - self.mouse_x)
	local dy = (self.last_mouse_down_event.y - self.mouse_y)
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance < self.MOUSE_CLICK_MAX_DISTANCE then
		local ce = MouseClickEvent(modifiers)
		ce.target = self.last_mouse_down_event.target
		ce.x = self.mouse_x
		ce.y = self.mouse_y
		ce.button = event[3]
		self:dispatchEvent(ce)
	end

	if self.last_drag_event then
		local de = DragEndEvent(modifiers)
		de.target = self.last_drag_event.target
		de.x = self.mouse_x
		de.y = self.mouse_y
		self:dispatchEvent(de)
		self.last_drag_event = nil
	end

	local e = MouseUpEvent(modifiers)
	e.button = event[3]
	self.last_mouse_down_event = nil
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers ui.ModifierKeys
---@return ui.ScrollEvent
function Inputs:handleWheel(event, modifiers)
	local e = ScrollEvent(modifiers)
	e.direction_x = event[1]
	e.direction_y = event[2]
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers ui.ModifierKeys
---@return ui.MouseEvent?
function Inputs:handleMouseMove(event, modifiers)
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
---@param modifiers ui.ModifierKeys
---@return ui.MouseEvent?
function Inputs:dispatchMouseEvent(event, modifiers)
	local e = nil ---@type ui.MouseEvent?

	if event.name == "mousepressed" then
		e = self:handleMouseDown(event, modifiers)

		if self.keyboard_focus then
			local is_descendant = false
			local current = self.mouse_target
			while current do
				if current == self.keyboard_focus then
					is_descendant = true
					break
				end
				current = current.parent
			end

			if not is_descendant then
				self:setKeyboardFocus(nil, modifiers)
			end
		end
	elseif event.name == "mousereleased" then
		e = self:handleMouseUp(event, modifiers)
	elseif event.name == "wheelmoved" then
		e = self:handleWheel(event, modifiers)
	elseif event.name == "mousemoved" then
		e = self:handleMouseMove(event, modifiers)
	end

	if not e then
		return
	end

	e.target = e.target or self.mouse_target
	e.x = self.mouse_x
	e.y = self.mouse_y
	self:dispatchEvent(e)
	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers ui.ModifierKeys
function Inputs:dispatchKeyboardEvent(event, modifiers)
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

	for _, v in ipairs(self.focus_requesters) do
		e.target = v
		local handled = self:dispatchEvent(e)
		if handled then
			break
		end
	end
end

---@param event {name: string, [integer]: any}
---@param modifiers ui.ModifierKeys
function Inputs:receive(event, modifiers)
	if mouse_events[event.name] then
		self:dispatchMouseEvent(event, modifiers)
	elseif keyboard_events[event.name] then
		self:dispatchKeyboardEvent(event, modifiers)
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
