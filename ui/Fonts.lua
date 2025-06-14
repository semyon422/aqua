local class = require("class")

---@class ui.Fonts
---@operator call: ui.Fonts
---@field fonts {[string]: string}
---@field sizes {[string]: {[number]: love.Font}}
---@field dpi number
local Fonts = class()

function Fonts:new()
	self.fonts = {}
	self.sizes = {}
	self.dpi = 1
end

---@param dpi number
function Fonts:setDPI(dpi)
	if self.dpi ~= dpi then
		for k, _ in pairs(self.sizes) do
			self.sizes[k] = {}
		end
	end
	self.dpi = dpi
end

---@param name string
---@param font_filepath string
function Fonts:add(name, font_filepath)
	self.fonts[name] = font_filepath
	self.sizes[name] = self.sizes[name] or {}
end

---@param name string
---@return boolean
function Fonts:isFontExists(name)
	return self.fonts[name] ~= nil
end

---@param name string
---@param size number
---@return love.Font
function Fonts:get(name, size)
	local cached = self.sizes[name][size]
	if cached then
		return cached
	end

	local path = self.fonts[name]
	local font = love.graphics.newFont(path, size, "light", self.dpi)
	self.sizes[name][size] = font
	return font
end

return Fonts
