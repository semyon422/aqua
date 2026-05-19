local class = require("class")

---@class ui.Composition
---@operator call: ui.Composition
---@field root ui.Composition.Node
local Composition = class()

---@param width number
---@param height number
function Composition:setDimensions(width, height)
	self.width = width
	self.height = height
end

---@param node ui.Composition.Node
function Composition:setRoot(node)
	self.root = node
end

function Composition:update()
	assert(self.root, "Composition needs root node")
	assert(self.width and self.height, "Composition needs dimensions to be set")
	self.root:measure()
	self.root:grow(self.width, self.height)
	self.root:arrange()
end

---@return ui.View[]
function Composition:getViews()
	local t = {}
	self.root:insertViewsInto(t)
	return t
end

return Composition
