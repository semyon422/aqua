local class = require("class")

---@class im.OverStack
---@operator call: im.OverStack
local OverStack = class()

function OverStack:new()
	---@type any[]
	self.ids = {}
	---@type boolean[]
	self.overs = {}
end

---@param id any
---@param over boolean
function OverStack:push(id, over)
	table.insert(self.ids, id)
	table.insert(self.overs, over)
end

---@return any?
function OverStack:pop()
	table.remove(self.overs)
	return table.remove(self.ids)
end

---@param depth integer?
---@return boolean
function OverStack:over(depth)
	local overs = self.overs
	local index = #overs - (depth or 1) + 1
	return #overs == 0 or overs[index]
end

---@return any?
function OverStack:id()
	return self.ids[#self.ids]
end

---@return integer
function OverStack:count()
	return #self.ids
end

function OverStack:step()
	assert(#self.ids == 0)
end

return OverStack
