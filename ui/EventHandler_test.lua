local Node = require("ui.Node")
local EventHandler = require("ui.EventHandler")

local test = {}

---@param t testing.T
function test.add_remove(t)
	local f = function () end
	local root = Node()
	local handler = EventHandler(root)
	root.event_handler = handler

	t:eq(handler.should_rebuild, false)
	local n1 = root:addChild(Node({ z = 1, update = f }))
	local n2 = root:addChild(Node({ z = 0.5, update = f }))
	local n3 = root:addChild(Node({ z = 0, update = f }))
	t:eq(handler.should_rebuild, true)

	handler:receive()
	t:teq(handler.events_listeners.update, {n1, n2, n3})

	n2:kill()
	handler:receive()
	t:teq(handler.events_listeners.update, {n1, n3})

	--------------------------------------

	root = Node()
	handler = EventHandler(root)
	root.event_handler = handler

	local modal = root:addChild(Node({id = "modal", z = 0.2}))
	local m_label = modal:addChild(Node({id = "label", z = 0.2, draw = f}))
	local m_button = modal:addChild(Node({id = "button", z = 0.5, draw = f, mousePressed = f}))

	local screen = root:addChild(Node({id = "screen", z = 0.1}))
	local s_button = screen:addChild(Node({id = "button", z = 999, draw = f, mousePressed = f}))
	local s_image = screen:addChild(Node({id = "image", z = 0, draw = f, mousePressed = f}))
	handler:receive()

	t:teq(handler.events_listeners.mousePressed, {m_button, s_button, s_image})
	t:teq(handler.events_listeners.draw, {m_button, m_label, s_button, s_image})

	s_image:kill()
	handler:receive()
	t:teq(handler.events_listeners.mousePressed, {m_button, s_button})
	t:teq(handler.events_listeners.draw, {m_button, m_label, s_button})
end

return test
