local class = require("class")

---@class ui.Fonts
---@operator call: ui.Fonts
---@field fonts {[string]: string}
local Fonts = class()

Fonts.FontSize = 50 -- Don't change at runtime

function Fonts:new()
	self.font_paths = {}
	self.instances = {}
end

---@param name string
---@param font_filepath string
function Fonts:add(name, font_filepath)
	self.font_paths[name] = font_filepath
end

---@param name string
---@return boolean
function Fonts:isFontExist(name)
	return self.font_paths[name] ~= nil
end

local font_params = { sdf = true, hinting = "normal" }

---@param name string
---@param size number
---@return love.Font
function Fonts:get(name)
	if not self:isFontExist(name) then
		error("Font doesn't exist")
	end

	local cached = self.instances[name]
	if cached then
		return cached
	end

	local path = self.font_paths[name]
	local font = love.graphics.newFont(path, Fonts.FontSize, font_params)
	self.instances[name] = font
	return font
end

return Fonts
