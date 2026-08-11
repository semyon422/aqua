local Transform = require("math.Transform")

---@class testing.FakeLove
local FakeLove = {}

local color = {1, 1, 1, 1}
---@type love.Canvas?
local current_canvas
local line_width = 1

local graphics = {}
function graphics.newCanvas(width, height)
	return {
		getWidth = function() return width end,
		getHeight = function() return height end,
		getDimensions = function() return width, height end,
		release = function(self) self.released = true end,
	}
end
function graphics.setColor(r, g, b, a) color = {r, g, b, a} end
function graphics.getColor() return unpack(color) end
function graphics.getCanvas() return current_canvas end
function graphics.setCanvas(canvas) current_canvas = canvas end
function graphics.getLineWidth() return line_width end
function graphics.setLineWidth(value) line_width = value end
function graphics.transformPoint(x, y) return x, y end
function graphics.replaceTransform() end
function graphics.setScissor() end
function graphics.setBlendMode() end
function graphics.clear() end
function graphics.origin() end
function graphics.draw() end
function graphics.translate() end
function graphics.push() end
function graphics.pop() end
function graphics.polygon() end
function graphics.newFont(_, size)
	return {
		getWidth = function(_, text) return #text end,
		getHeight = function() return size or 12 end,
		setFallbacks = function() end,
	}
end

---@return boolean installed
function FakeLove.install()
	if _G.love then
		return false
	end
	_G.love = {
		graphics = graphics,
		math = {newTransform = Transform},
		timer = {getTime = os.clock},
		mouse = {getPosition = function() return 0, 0 end},
		filesystem = {
			getInfo = function() return nil end,
			read = function() return nil, "file not found" end,
		},
		window = {hasFocus = function() return true end},
		system = {getOS = function() return "Linux" end},
	}
	return true
end

function FakeLove.uninstall()
	_G.love = nil
end

return FakeLove
