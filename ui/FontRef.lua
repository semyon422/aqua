local class = require("class")

---@class ui.FontRef
---@overload fun(object: love.Font, path: string, size: integer): ui.FontRef
---@field object love.Font
---@field path string
---@field size integer
--- love.Font reference object. Used for hot reload of fonts
local FontRef = class()

---@param object love.Font
---@param path string
---@param size integer
function FontRef:new(object, path, size)
	self.object = object
	self.path = path
	self.size = size
	self.is_released = false
end

---@return love.Font
function FontRef:get()
	return self.object
end

---@param font love.Font
function FontRef:replaceFont(font)
	if not self.is_released then
		self.object:release()
	end
	self.is_released = false
	self.object = font
end

---@param text string
---@return number w
function FontRef:getWidth(text)
	return self.object:getWidth(text)
end

---@return number h
function FontRef:getHeight()
	return self.object:getHeight()
end

---@return number w
---@return number h
function FontRef:getDimensions()
	return self.object:getDimensions()
end

function FontRef:release()
	self.object:release()
	self.is_released = true
end

---@return boolean
function FontRef:isReleased()
	return self.is_released
end

return FontRef
