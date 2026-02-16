local class = require("class")

---@class ui.TextBatchRef
---@overload fun(text_batch: love.Text): ui.TextBatchRef
local TextBatchRef = class()

---@param text_batch love.Text
function TextBatchRef:new(text_batch)
	self.object = text_batch
	self.is_released = false
end

---@return love.Text
function TextBatchRef:get()
	return self.object
end

---@param text string
function TextBatchRef:setText(text)
	self.object:set(text)
end

---@return number w
function TextBatchRef:getWidth()
	return self.object:getWidth()
end

---@return number h
function TextBatchRef:getHeight()
	return self.object:getHeight()
end

---@return number w
---@return number h
function TextBatchRef:getDimensions()
	return self.object:getDimensions()
end

function TextBatchRef:release()
	self.object:release()
	self.is_released = true
end

---@return boolean
function TextBatchRef:isReleased()
	return self.is_released
end

return TextBatchRef
