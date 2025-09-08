local Button = require("im.Button")
local MouseInput = require("im.MouseInput")

local test = {}

---@param t testing.T
function test.all(t)
	local state = {active_id = nil}
	local mouse = MouseInput()

	local button = Button(state, mouse)

	t:tdeq({button:button(1, false)}, {nil, false, false})
	t:tdeq({button:button(1, true)}, {nil, false, true})

	mouse:step()
	mouse:mousepressed(1)
	t:tdeq({button:button(1, true)}, {nil, true, true})
	t:tdeq({button:button(1, false)}, {nil, false, false})
	t:tdeq({button:button(1, true)}, {nil, true, true})

	mouse:step()
	mouse:mousereleased(1)
	t:tdeq({button:button(1, true)}, {1, false, true})
	t:tdeq({button:button(1, true)}, {nil, false, true})

	mouse:step()
	mouse:mousepressed(1)
	t:tdeq({button:button(1, true)}, {nil, true, true})

	mouse:step()
	mouse:mousereleased(1)
	t:tdeq({button:button(1, false)}, {nil, false, false})
end

return test
