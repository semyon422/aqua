local Inputs = require("ui.input.Inputs")
local TraversalContext = require("ui.input.TraversalContext")
local IInputHandler = require("ui.input.IInputHandler")

local test = {}

local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@return ui.Node
local function new_node()
	local node = {
		children = {},
		add = function(self, node)
			table.insert(self.children, node)
			node.parent = self
			return node
		end,
	}
	setmetatable(node, {__index = IInputHandler})
	return node
end

---@param t testing.T
function test.bubbling(t)
	local root = new_node()
	root:add(new_node())

	local c1 = root:add(new_node())
	local c2 = c1:add(new_node())
	local inputs = Inputs()
	local tctx = TraversalContext()

	root:add(new_node())

	local order = {}
	local expected_order = {"c1", "root"}

	root.onMouseDown = function()
		table.insert(order, "root")
	end

	c1.onMouseDown = function()
		table.insert(order, "c1")
	end

	c2.onMouseDown = function()
		table.insert(order, "c2")
	end

	local x = 0
	local y = 0
	local button = 1
	local event = {name = "mousepressed", x, y, button}
	tctx.mouse_target = c1
	inputs:receive(event, tctx, default_modifiers)

	t:teq(order, expected_order)

	order = {}
	expected_order = {"c2", "c1", "root"}
	tctx.mouse_target = c2
	inputs:receive(event, tctx, default_modifiers)
	t:teq(order, expected_order)
	t:teq(order, expected_order)
end

---@param t testing.T
function test.mouse_click(t)
	local root = new_node()
	local btn = root:add(new_node())
	local inputs = Inputs()
	local tctx = TraversalContext()

	local events = {}
	btn.onMouseDown = function() table.insert(events, "down") end
	btn.onMouseUp = function() table.insert(events, "up") end
	btn.onMouseClick = function() table.insert(events, "click") end

	tctx.mouse_target = btn
	tctx.mouse_x = 10
	tctx.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, tctx, default_modifiers)
	inputs:receive({name = "mousereleased", 10, 10, 1}, tctx, default_modifiers)

	t:teq(events, {"down", "click", "up"})

	-- No click
	events = {}
	inputs:receive({name = "mousepressed", 10, 10, 1}, tctx, default_modifiers)

	tctx.mouse_x = 9999999999
	tctx.mouse_y = 9999999999
	inputs:receive({name = "mousemoved", 100, 100, 0, 0}, tctx, default_modifiers)

	inputs:receive({name = "mousereleased", 100, 100, 1}, tctx, default_modifiers)

	t:teq(events, {"down", "up"})
	t:teq(events, {"down", "up"})
end

---@param t testing.T
function test.keyboard_focus(t)
	local root = new_node()
	local textbox1 = root:add(new_node())
	local textbox2 = root:add(new_node())
	local inputs = Inputs()
	local tctx = TraversalContext()

	local events1 = {}
	local events2 = {}

	textbox1.onFocus = function() table.insert(events1, "focus") end
	textbox1.onFocusLost = function() table.insert(events1, "blur") end
	textbox1.onTextInput = function(_, event) table.insert(events1, "text:" .. event.key) end

	textbox2.onFocus = function() table.insert(events2, "focus") end
	textbox2.onFocusLost = function() table.insert(events2, "blur") end
	textbox2.onTextInput = function(_, event) table.insert(events2, "text:" .. event.key) end

	inputs:setKeyboardFocus(textbox1, default_modifiers)
	t:teq(events1, {"focus"})
	t:teq(events2, {})

	inputs:receive({name = "textinput", "a"}, tctx, default_modifiers)
	t:teq(events1, {"focus", "text:a"})
	t:teq(events2, {})

	inputs:setKeyboardFocus(textbox2, default_modifiers)
	t:teq(events1, {"focus", "text:a", "blur"})
	t:teq(events2, {"focus"})

	inputs:receive({name = "textinput", "b"}, tctx, default_modifiers)
	t:teq(events1, {"focus", "text:a", "blur"})
	t:teq(events2, {"focus", "text:b"})

	inputs:setKeyboardFocus(nil, default_modifiers)
	t:teq(events2, {"focus", "text:b", "blur"})
end

---@param t testing.T
function test.dragging(t)
	local root = new_node()
	local draggable = root:add(new_node())
	local inputs = Inputs()
	local tctx = TraversalContext()

	local events = {}
	draggable.onDragStart = function() table.insert(events, "start") end
	draggable.onDrag = function() table.insert(events, "drag") end
	draggable.onDragEnd = function() table.insert(events, "end") end

	tctx.mouse_target = draggable
	tctx.mouse_x = 10
	tctx.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, tctx, default_modifiers)
	t:teq(events, {})

	-- start
	tctx.mouse_x = 15
	tctx.mouse_y = 15
	inputs:receive({name = "mousemoved", 15, 15, 5, 5}, tctx, default_modifiers)
	t:teq(events, {"start"})

	-- continue
	tctx.mouse_x = 20
	tctx.mouse_y = 20
	inputs:receive({name = "mousemoved", 20, 20, 5, 5}, tctx, default_modifiers)
	t:teq(events, {"start", "drag"})

	-- end
	inputs:receive({name = "mousereleased", 20, 20, 1}, tctx, default_modifiers)
	t:teq(events, {"start", "drag", "end"})
end

---@param t testing.T
function test.scrolling(t)
	local root = new_node()
	local scrollable = root:add(new_node())
	local inputs = Inputs()
	local tctx = TraversalContext()

	local events = {}
	scrollable.onScroll = function(self, e) table.insert(events, {e.direction_x, e.direction_y}) end

	tctx.mouse_target = scrollable
	inputs:receive({name = "wheelmoved", 0, 1}, tctx, default_modifiers)

	t:tdeq(events, {{0, 1}})
end

return test
