local SphereTreeRoot = require("ui.SphereTreeRoot")
local Node = require("ui.Node")

local test = {}

---@param t testing.T
function test.events(t)
	local root = SphereTreeRoot()
	root:registerEvent("sphere_testEvent")

	local triggered = {}
	local f = function(self)
		triggered[self.id] = triggered[self.id] or 0
		triggered[self.id] = triggered[self.id] + 1
	end

	local n1 = root:addChild(Node({id = "n1", sphere_testEvent = f}))
	local n2 = root:addChild(Node({id = "n2",  sphere_testEvent = f}))
	local n2c1 = n2:addChild(Node({id = "n2c1", sphere_testEvent = f}))
	local n2c2 = n2:addChild(Node({id = "n2c2", sphere_testEvent = f}))
	local n3 = root:addChild(Node({id = "n3", sphere_testEvent = f}))

	root:dispatchEvent("sphere_testEvent")
	t:teq(root.event_listeners["sphere_testEvent"], {[n1] = true, [n2] = true, [n2c1] = true, [n2c2] = true, [n3] = true})
	t:teq(triggered, {n1 = 1, n2 = 1, n2c1 = 1, n2c2 = 1, n3 = 1})

	root:dispatchEvent("sphere_testEvent")
	t:teq(triggered, {n1 = 2, n2 = 2, n2c1 = 2, n2c2 = 2, n3 = 2})

	root:registerEvent("sphere_otherEvent")
	root:dispatchEvent("sphere_otherEvent")
	t:teq(triggered, {n1 = 2, n2 = 2, n2c1 = 2, n2c2 = 2, n3 = 2})

	n2c2:kill()
	triggered = {}
	root:dispatchEvent("sphere_testEvent")
	t:teq(root.event_listeners["sphere_testEvent"], {[n1] = true, [n2] = true, [n2c1] = true, [n3] = true})
	t:teq(triggered, {n1 = 1, n2 = 1, n2c1 = 1, n3 = 1})

	n2:kill()
	triggered = {}
	root:dispatchEvent("sphere_testEvent")
	t:teq(root.event_listeners["sphere_testEvent"], {[n1] = true, [n3] = true})
	t:teq(triggered, {n1 = 1, n3 = 1})
end

function test.cancelable_events(t)
	local root = SphereTreeRoot()
	root:registerEvent("mousePressed", true)

	local order = {}
	local f = function(self)
		table.insert(order, self)
	end

	local n1 = root:addChild(Node({z = 1, mousePressed = f}))
	local n2 = root:addChild(Node({z = 0.5, mousePressed = f}))
	local n2c1 = n2:addChild(Node({z = 999, mousePressed = f}))
	local n2c2 = n2:addChild(Node({z = -999, mousePressed = f}))
	local n3 = root:addChild(Node({mousePressed = f}))

	root:update()
	root:dispatchEvent("mousePressed")
	t:teq(order, {n1, n2, n2c1, n2c2, n3})
end

return test
