local Node = require("ui.Node")
local Inputs = require("ui.input.Inputs")

local test = {}

local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param node ui.Node
---@param width number
---@param height number
local function set_node_size(node, width, height)
	node.layout_box.x.size = width
	node.layout_box.y.size = height
end

---@param t testing.T
function test.bubbling(t)
	local root = Node()
	root:add(Node()) -- random Node

	local c1 = root:add(Node())
	local c2 = c1:add(Node())
	local inputs = Inputs()

	root:add(Node()) -- random Node

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
	inputs.mouse_target = c1
	inputs:receive(event, default_modifiers)

	t:tdeq(order, expected_order)

	order = {}
	expected_order = {"c2", "c1", "root"}
	inputs.mouse_target = c2
	inputs:receive(event, default_modifiers)
	t:tdeq(order, expected_order)
end

---@param t testing.T
function test.mouse_click(t)
	local root = Node()
	local btn = root:add(Node())
	local inputs = Inputs()

	local events = {}
	btn.onMouseDown = function() table.insert(events, "down") end
	btn.onMouseUp = function() table.insert(events, "up") end
	btn.onMouseClick = function() table.insert(events, "click") end

	inputs.mouse_target = btn
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs:receive({name = "mousereleased", 10, 10, 1}, default_modifiers)

	t:tdeq(events, {"down", "click", "up"})

	-- No click
	events = {}
	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)

	inputs.mouse_x = 9999999999
	inputs.mouse_y = 9999999999
	inputs:receive({name = "mousemoved", 100, 100, 0, 0}, default_modifiers)

	inputs:receive({name = "mousereleased", 100, 100, 1}, default_modifiers)

	t:tdeq(events, {"down", "up"})
end

---@param t testing.T
function test.keyboard_focus(t)
	local root = Node()
	local textbox1 = root:add(Node())
	local textbox2 = root:add(Node())
	local inputs = Inputs()

	local events1 = {}
	local events2 = {}

	textbox1.onFocus = function() table.insert(events1, "focus") end
	textbox1.onFocusLost = function() table.insert(events1, "blur") end
	textbox1.onTextInput = function(_, event) table.insert(events1, "text:" .. event.key) end

	textbox2.onFocus = function() table.insert(events2, "focus") end
	textbox2.onFocusLost = function() table.insert(events2, "blur") end
	textbox2.onTextInput = function(_, event) table.insert(events2, "text:" .. event.key) end

	inputs:setKeyboardFocus(textbox1, default_modifiers)
	t:tdeq(events1, {"focus"})
	t:tdeq(events2, {})

	inputs:receive({name = "textinput", "a"}, default_modifiers)
	t:tdeq(events1, {"focus", "text:a"})
	t:tdeq(events2, {})

	inputs:setKeyboardFocus(textbox2, default_modifiers)
	t:tdeq(events1, {"focus", "text:a", "blur"})
	t:tdeq(events2, {"focus"})

	inputs:receive({name = "textinput", "b"}, default_modifiers)
	t:tdeq(events1, {"focus", "text:a", "blur"})
	t:tdeq(events2, {"focus", "text:b"})

	inputs:setKeyboardFocus(nil, default_modifiers)
	t:tdeq(events2, {"focus", "text:b", "blur"})
end

---@param t testing.T
function test.mousepressed_clears_keyboard_focus_if_outside(t)
	local inputs = Inputs()
	local node1 = Node()
	local node2 = Node()
	
	node1.onFocus = function() end
	node1.onFocusLost = function() end

	-- Set focus on node1
	inputs:setKeyboardFocus(node1, default_modifiers)
	t:eq(inputs.keyboard_focus, node1)

	-- Click on node1: focus stays
	inputs.mouse_target = node1
	inputs:receive({name = "mousepressed", 0, 0, 1}, default_modifiers)
	t:eq(inputs.keyboard_focus, node1)

	-- Click on child of node1: focus stays
	local child = node1:add(Node())
	inputs.mouse_target = child
	inputs:receive({name = "mousepressed", 0, 0, 1}, default_modifiers)
	t:eq(inputs.keyboard_focus, node1)

	-- Click on node2 (outside): focus cleared
	inputs.mouse_target = node2
	inputs:receive({name = "mousepressed", 0, 0, 1}, default_modifiers)
	t:eq(inputs.keyboard_focus, nil)
end

---@param t testing.T
function test.dragging(t)
	local root = Node()
	local draggable = root:add(Node())
	local inputs = Inputs()

	local events = {}
	draggable.onDragStart = function() table.insert(events, "start") end
	draggable.onDrag = function() table.insert(events, "drag") end
	draggable.onDragEnd = function() table.insert(events, "end") end

	inputs.mouse_target = draggable
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	t:tdeq(events, {})

	-- start
	inputs.mouse_x = 15
	inputs.mouse_y = 15
	inputs:receive({name = "mousemoved", 15, 15, 5, 5}, default_modifiers)
	t:tdeq(events, {"start"})

	-- continue
	inputs.mouse_x = 20
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 20, 20, 5, 5}, default_modifiers)
	t:tdeq(events, {"start", "drag"})

	-- end
	inputs:receive({name = "mousereleased", 20, 20, 1}, default_modifiers)
	t:tdeq(events, {"start", "drag", "end"})
end

---@param t testing.T
function test.scrolling(t)
	local root = Node()
	local scrollable = root:add(Node())
	local inputs = Inputs()

	local events = {}
	scrollable.onScroll = function(self, e) table.insert(events, {e.direction_x, e.direction_y}) end

	inputs.mouse_target = scrollable
	inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:tdeq(events, {{0, 1}})
end

-- ============================================
-- processNode tests
-- ============================================

---@param t testing.T
function test.processNode_sets_mouse_target(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node = Node()
	node.handles_mouse_input = true
	set_node_size(node, 100, 100)

	inputs:processNode(node)

	t:eq(inputs.mouse_target, node)
end

---@param t testing.T
function test.processNode_does_not_set_mouse_target_if_not_handling(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node = Node()
	node.handles_mouse_input = false
	set_node_size(node, 100, 100)

	inputs:processNode(node)

	t:eq(inputs.mouse_target, nil)
end

---@param t testing.T
function test.processNode_does_not_override_existing_mouse_target(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node1 = Node()
	node1.handles_mouse_input = true
	set_node_size(node1, 100, 100)

	local node2 = Node()
	node2.handles_mouse_input = true
	set_node_size(node2, 100, 100)

	inputs:processNode(node1)
	inputs:processNode(node2)

	t:eq(inputs.mouse_target, node1)
end

---@param t testing.T
function test.processNode_detects_mouse_outside(t)
	local inputs = Inputs()
	inputs:beginFrame(150, 150) -- Outside the node

	local node = Node()
	node.handles_mouse_input = true
	set_node_size(node, 100, 100)

	inputs:processNode(node)

	t:eq(inputs.mouse_target, nil)
	t:eq(node.mouse_over, false)
end

---@param t testing.T
function test.processNode_dispatches_hover_event(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node = Node()
	node.handles_mouse_input = true
	set_node_size(node, 100, 100)

	local hover_called = false
	node.onHover = function(self, e)
		hover_called = true
		t:eq(e.target, node)
	end

	inputs:processNode(node)

	t:assert(hover_called, "onHover should be called")
	t:eq(node.mouse_over, true)
end

---@param t testing.T
function test.processNode_dispatches_hover_lost_event(t)
	local inputs = Inputs()
	local node = Node()
	node.handles_mouse_input = true
	node.mouse_over = true -- Already hovered
	set_node_size(node, 100, 100)

	local hover_lost_called = false
	node.onHoverLost = function(self, e)
		hover_lost_called = true
		t:eq(e.target, node)
	end

	-- Move mouse outside
	inputs:beginFrame(150, 150)
	inputs:processNode(node)

	t:assert(hover_lost_called, "onHoverLost should be called")
	t:eq(node.mouse_over, false)
end

---@param t testing.T
function test.processNode_no_hover_event_when_staying_hovered(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node = Node()
	node.handles_mouse_input = true
	node.mouse_over = true -- Already hovered
	set_node_size(node, 100, 100)

	local hover_called = false
	node.onHover = function()
		hover_called = true
	end

	inputs:processNode(node)

	t:assert(not hover_called, "onHover should not be called when already hovered")
	t:eq(node.mouse_over, true)
end

---@param t testing.T
function test.processNode_no_hover_lost_event_when_staying_outside(t)
	local inputs = Inputs()
	inputs:beginFrame(150, 150)

	local node = Node()
	node.handles_mouse_input = true
	node.mouse_over = false -- Already not hovered
	set_node_size(node, 100, 100)

	local hover_lost_called = false
	node.onHoverLost = function()
		hover_lost_called = true
	end

	inputs:processNode(node)

	t:assert(not hover_lost_called, "onHoverLost should not be called when already not hovered")
	t:eq(node.mouse_over, false)
end

---@param t testing.T
function test.processNode_adds_focus_requester(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node = Node()
	node.handles_keyboard_input = true
	set_node_size(node, 100, 100)

	inputs:processNode(node)

	t:eq(#inputs.focus_requesters, 1)
	t:eq(inputs.focus_requesters[1], node)
end

---@param t testing.T
function test.processNode_adds_multiple_focus_requesters(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node1 = Node()
	node1.handles_keyboard_input = true
	set_node_size(node1, 100, 100)

	local node2 = Node()
	node2.handles_keyboard_input = true
	set_node_size(node2, 100, 100)

	local node3 = Node()
	node3.handles_keyboard_input = true
	set_node_size(node3, 100, 100)

	inputs:processNode(node1)
	inputs:processNode(node2)
	inputs:processNode(node3)

	t:eq(#inputs.focus_requesters, 3)
	t:eq(inputs.focus_requesters[1], node1)
	t:eq(inputs.focus_requesters[2], node2)
	t:eq(inputs.focus_requesters[3], node3)
end

---@param t testing.T
function test.processNode_node_with_both_input_types(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	local node = Node()
	node.handles_mouse_input = true
	node.handles_keyboard_input = true
	set_node_size(node, 100, 100)

	inputs:processNode(node)

	t:eq(inputs.mouse_target, node)
	t:eq(#inputs.focus_requesters, 1)
	t:eq(inputs.focus_requesters[1], node)
end

---@param t testing.T
function test.processNode_clears_mouse_over_when_mouse_target_already_set(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	-- First node captures mouse target
	local node1 = Node()
	node1.handles_mouse_input = true
	set_node_size(node1, 100, 100)

	-- Second node was hovered but won't get mouse_target
	local node2 = Node()
	node2.handles_mouse_input = true
	node2.mouse_over = true -- Was hovered
	set_node_size(node2, 100, 100)

	local hover_lost_called = false
	node2.onHoverLost = function()
		hover_lost_called = true
	end

	inputs:processNode(node1)
	inputs:processNode(node2)

	t:assert(hover_lost_called, "onHoverLost should be called when node loses mouse_target to another")
	t:eq(node2.mouse_over, false)
end

---@param t testing.T
function test.processNode_tree_traversal(t)
	local inputs = Inputs()
	inputs:beginFrame(50, 50)

	-- Create tree:
	-- root (100x100)
	-- ├── container (100x100, handles_mouse)
	-- │   ├── button (50x50 at relative position, handles_mouse)
	-- │   └── textbox (handles_keyboard)
	-- └── other (handles_mouse, but mouse is not over it)

	local root = Node()
	set_node_size(root, 100, 100)

	local container = Node()
	container.handles_mouse_input = true
	set_node_size(container, 100, 100)

	local button = Node()
	button.handles_mouse_input = true
	set_node_size(button, 50, 50)

	local textbox = Node()
	textbox.handles_keyboard_input = true
	set_node_size(textbox, 100, 100)

	local other = Node()
	other.handles_mouse_input = true
	set_node_size(other, 100, 100)

	-- Process in tree order
	inputs:processNode(root)
	inputs:processNode(container)
	inputs:processNode(button)
	inputs:processNode(textbox)
	inputs:processNode(other)

	-- First mouse-handling node under cursor should be target
	t:eq(inputs.mouse_target, container)
	-- All keyboard-handling nodes should be collected
	t:eq(#inputs.focus_requesters, 1)
	t:eq(inputs.focus_requesters[1], textbox)
end

---@param t testing.T
function test.beginFrame_resets_context(t)
	local inputs = Inputs()

	-- Set up some state
	inputs.mouse_x = 100
	inputs.mouse_y = 100
	inputs.mouse_target = Node()
	table.insert(inputs.focus_requesters, Node())

	-- Begin new frame
	inputs:beginFrame(50, 75)

	t:eq(inputs.mouse_x, 50)
	t:eq(inputs.mouse_y, 75)
	t:eq(inputs.mouse_target, nil)
	t:eq(#inputs.focus_requesters, 0)
end

return test
