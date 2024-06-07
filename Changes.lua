local class = require("class")

---@class util.Changes
---@operator call: util.Changes
local Changes = class()

function Changes:new()
	self[1] = 0
	self.index = 2
end

---@return number
function Changes:get()
	local i = self.index
	return self[i] or self[i - 1] or 0
end

---@return number
function Changes:add()
	local i = self.index
	self[i] = self:get() + 1
	return self[i]
end

---@return number
function Changes:next()
	if not self[self.index] then
		return self:get()
	end
	self.index = self.index + 1
	return self:get()
end

function Changes:reset()
	for i = self.index, #self do
		self[i] = nil
	end
end

---@param _changes util.Changes
---@param index number
---@return number?
local function undo(_changes, index)
	local changeStart, changeEnd = _changes[_changes.index - 1], _changes[_changes.index - 2]
	if not changeEnd then
		return
	end
	index = (index or changeStart + 1) - 1
	if index == changeEnd then
		_changes.index = _changes.index - 1
		return
	end
	return index
end

---@param _changes util.Changes
---@param index number
---@return number?
local function redo(_changes, index)
	local changeStart, changeEnd = _changes[_changes.index - 1], _changes[_changes.index]
	if not changeEnd then
		return
	end
	index = (index or changeStart) + 1
	if index == changeEnd + 1 then
		_changes.index = _changes.index + 1
		return
	end
	return index
end

---@return function
---@return util.Changes
function Changes:undo()
	return undo, self
end

---@return function
---@return util.Changes
function Changes:redo()
	return redo, self
end

---@return string
function Changes:__tostring()
	local t = {}
	for i = 1, #self do
		t[i] = self[i]
		if i == self.index then
			t[i] = ("[%s]"):format(self[i])
		end
	end
	if self.index > #self then
		t[self.index] = "[_]"
	end
	return table.concat(t, ",")
end

return Changes
