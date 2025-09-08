local class = require("class")
local Depth = require("im.Depth")
local OverStack = require("im.OverStack")

---@class im.ContDepth
---@operator call: im.ContDepth
local ContDepth = class()

function ContDepth:new()
	self.depth = Depth()
	self.over_stack = OverStack()
end

---@param id any
---@param over boolean
---@return boolean
function ContDepth:over(id, over)
	if not self.over_stack:over() then
		return false
	end
	return self.depth:over(id, over)
end

---@param id any
---@param over boolean
function ContDepth:push(id, over)
	self.over_stack:push(id, over)
end

---@return any?
function ContDepth:pop()
	return self.over_stack:pop()
end

function ContDepth:step()
	self.depth:step()
	self.over_stack:step()
end

return ContDepth
