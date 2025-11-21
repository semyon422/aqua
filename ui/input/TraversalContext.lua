local class = require("class")
require("table.clear")

---@class ui.TraversalContext
---@operator call: ui.TraversalContext
---@field mouse_x number
---@field mouse_y number
---@field mouse_target ui.Inputs.Node?
---@field focus_requesters ui.Inputs.Node[]
local TraversalContext = class()

function TraversalContext:new()
	self.mouse_x = 0
	self.mouse_y = 0
	self.mouse_target = nil
	self.focus_requesters = {}
end

function TraversalContext:reset()
	self.mouse_target = nil
	table.clear(self.focus_requesters)
end

return TraversalContext
