local Class = require("Class")

local Changes = Class:new()

function Changes:construct()
	self[1] = 0
	self.index = 2
end

function Changes:get()
	local i = self.index
	return self[i] or self[i - 1] or 0
end

function Changes:add()
	local i = self.index
	self[i] = self:get() + 1
	return self[i]
end

function Changes:next()
	self.index = self.index + 1
	return self:get()
end

function Changes:reset()
	for i = self.index, #self do
		self[i] = nil
	end
end

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

function Changes:undo()
	return undo, self
end

function Changes:redo()
	return redo, self
end

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
