local View = require("ui.View")

---@class ui.Container : ui.View
---@operator call: ui.Container
---@field children ui.View[]
local Container = View + {}

function Container:new()
	View.new(self)
	self.children = {}
end

function Container:update(dt)
	for _, v in ipairs(self.children) do
		v:update(dt)
	end
end

function Container:updateTransform()
	View.updateTransform(self)

	for _, v in ipairs(self.children) do
		v.box = self.box
		v:updateTransform()
	end
end

local lg = love.graphics

function Container:draw()
	lg.pop()
	for _, v in ipairs(self.children) do
		lg.push("all")
		lg.applyTransform(v.transform)
		v:draw()
		lg.pop()
	end
	lg.push()
	lg.applyTransform(self.transform)
end

function Container:acceptInputs(inputs)
	for i = #self.children, 1, -1 do
		local c = self.children[i]
		c:acceptInputs(inputs)
	end
end

return Container
