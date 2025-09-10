local Viewport = require("ui.Viewport")
local Tree = require("ui.simple.DevTools.Tree")
local Selection = require("ui.simple.DevTools.Selection")

---@class ui.Simple.DevTools
---@operator call: ui.Simple.DevTools
local DevTools = Viewport + {}

function DevTools:load()
	self:add(Tree({
		anchor = self.Pivot.TopRight,
		origin = self.Pivot.TopRight,
		width = 250,
		height = 768,
		root = self.target_node,
		fonts = self.fonts
	}))

	self.selection = self:add(Selection())
end

function DevTools:selectDrawable(d)
	self.selection:setTarget(d)
end

function DevTools:drawChildren()
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)

	for i = #self.children, 1, -1 do
		local child = self.children[i]
		love.graphics.push("all")
		child:drawTree()
		love.graphics.pop()
	end
end

return DevTools
