local EventHandler = require("ui.EventHandler")
local Node = require("ui.Node")

local test = {}

---@param t testing.T
function test.events(t)
	local event_handler = EventHandler()
	event_handler:registerEvent("sphere_testEvent")
	event_handler:registerEvent("sphere_otherEvent")

	local root = Node({event_handler = event_handler})
	event_handler:setRoot(root)

	local triggered = {}
	local f = function(self)
		triggered[self.id] = triggered[self.id] or 0
		triggered[self.id] = triggered[self.id] + 1
	end

	local n1 = root:add(Node({id = "n1", sphere_testEvent = f}))
	local n2 = root:add(Node({id = "n2",  sphere_testEvent = f}))
	local n2c1 = n2:add(Node({id = "n2c1", sphere_testEvent = f}))
	local n2c2 = n2:add(Node({id = "n2c2", sphere_testEvent = f}))
	local n3 = root:add(Node({id = "n3", sphere_testEvent = f}))

	event_handler:dispatchEvent("sphere_testEvent")
	t:teq(event_handler.event_listeners["sphere_testEvent"], {n1, n2, n2c1, n2c2, n3})
	t:teq(triggered, {n1 = 1, n2 = 1, n2c1 = 1, n2c2 = 1, n3 = 1})

	event_handler:dispatchEvent("sphere_testEvent")
	t:teq(triggered, {n1 = 2, n2 = 2, n2c1 = 2, n2c2 = 2, n3 = 2})

	event_handler:dispatchEvent("sphere_otherEvent")
	t:teq(triggered, {n1 = 2, n2 = 2, n2c1 = 2, n2c2 = 2, n3 = 2})

	n2c2:kill()
	triggered = {}
	event_handler:dispatchEvent("sphere_testEvent")
	t:teq(event_handler.event_listeners["sphere_testEvent"], {n1, n2, n2c1, n3})
	t:teq(triggered, {n1 = 1, n2 = 1, n2c1 = 1, n3 = 1})

	n2:kill()
	triggered = {}
	event_handler:dispatchEvent("sphere_testEvent")
	t:teq(event_handler.event_listeners["sphere_testEvent"], {n1, n3})
	t:teq(triggered, {n1 = 1, n3 = 1})
end

---@param t testing.T
function test.interrupt(t)
	local event_handler = EventHandler()
	event_handler:registerEvent("keyPressed")

	local root = Node({event_handler = event_handler})
	event_handler:setRoot(root)

	local order = {}

	local n1 = root:add(Node({
		z = 0.1,
		keyPressed = function(self)
			table.insert(order, self)
		end
	}))
	local n2 = root:add(Node({
		z = 0.2,
		keyPressed = function(self)
			table.insert(order, self)
			return true
		end
	}))
	local n3 = root:add(Node({
		z = 0.3,
		keyPressed = function(self)
			table.insert(order, self)
		end
	}))

	event_handler:dispatchEvent("keyPressed")

	t:teq(order, {n3, n2})
end

---@param t testing.T
function test.focus(t)
	local event_handler = EventHandler()
	event_handler:registerEvent("keyPressed")
	event_handler:registerEvent("textInput")

	local root = Node({event_handler = event_handler})
	event_handler:setRoot(root)

	local receivers = {}
	local f = function(self)
		table.insert(receivers, self)
	end

	local modal = root:add(Node({z = 0.9, keyPressed = f}))
	local text_box = modal:add(Node({z = 0.5, textInput = f, keyPressed = f}))
	local exit_button = modal:add(Node({z = 1, keyPressed = f}))
	local screen = root:add(Node({z = 0.1, keyPressed = f}))
	local search = screen:add(Node({z = 0.1, textInput = f}))

	event_handler:dispatchEvent("keyPressed")
	t:teq(receivers, {modal, exit_button, text_box, screen})

	receivers = {}
	event_handler:dispatchEvent("textInput")
	t:teq(receivers, {text_box, search})

	receivers = {}
	root.event_handler:setFocus(text_box, "textInput")
	root.event_handler:setFocus(text_box, "keyPressed")
	event_handler:dispatchEvent("keyPressed")
	t:teq(receivers, {text_box})

	receivers = {}
	event_handler:dispatchEvent("textInput")
	t:teq(receivers, {text_box})

	receivers = {}
	root.event_handler:clearFocus(text_box)
	event_handler:dispatchEvent("textInput")
	t:teq(receivers, {text_box, search})

	receivers = {}
	root.event_handler:setFocus(text_box, "textInput")
	text_box:kill()
	event_handler:dispatchEvent("textInput")
	t:teq(receivers, {search})
end

return test
