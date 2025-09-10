local Drawable = require("ui.Drawable")

---@class ui.Simple.DevToolsTree
---@operator calL: ui.Simple.DevToolsTree
local Tree = Drawable + {}

Tree.handles_mouse_input = true

function Tree:load()
	self:ensureExist("root")
	self.font = self.fonts:get("Regular", 16)
	self.width = self.width or 250
	self.height = self.height or 250
end

function Tree:onMouseClick()
	self.parent:selectDrawable(self.hover_over)
end

---@param t {name: string, drawable: ui.Drawable}[]
---@param drawable ui.Drawable
local function dump_tree(t, drawable, depth)
	table.insert(t, {
		drawable = drawable,
		name = drawable.id or drawable.ClassName or "<no-id>",
		depth = depth
	})

	for _, child in ipairs(drawable.children) do
		dump_tree(t, child, depth + 1)
	end
end

function Tree:draw()
	local dump = {}
	dump_tree(dump, self.root, 0)

	love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
	love.graphics.rectangle("fill", 0, 0, self:getWidth(), self:getHeight())

	love.graphics.setFont(self.font)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.translate(5, 0)
	local h = self.font:getHeight() + 4
	for i, v in ipairs(dump) do
		love.graphics.setColor(1, 1, 1, 0.5)
		local imx, imy = love.graphics.inverseTransformPoint(love.mouse.getPosition())

		if self.mouse_over and imy > 0 and imy < h then
			self.hover_over = v.drawable
			love.graphics.setColor(1, 1, 1, 1)
		end

		love.graphics.print(v.name, v.depth * 12, 0)
		love.graphics.translate(0, h)
	end
end

return Tree
