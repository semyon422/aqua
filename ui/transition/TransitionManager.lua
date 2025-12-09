local class = require("class")

---@class ui.TransitionManager
---@operator call: ui.TransitionManager
local TransitionManager = class()

function TransitionManager:new()
	self.active = {} ---@type {[table]: ui.Transition[]}
end

---@param owner table
---@param transition ui.Transition
function TransitionManager:add(owner, transition)
	self.active[owner] = self.active[owner] or {}
	table.insert(self.active[owner], transition)
end

function TransitionManager:clear(owner)
	local transitions = self.active[owner]

	if not transitions then
		return
	end

	for _, v in ipairs(transitions) do
		v:markCompleted()
	end

	self.active[owner] = {}
end

---@param dt number
function TransitionManager:update(dt)
	for _, owner in pairs(self.active) do
		for _, transition in ipairs(owner) do
			if not transition.is_completed then
				transition:update(dt)
			end
		end
	end
end

function TransitionManager:removeOwner(owner)
	local transitions = self.active[owner]
	if not transitions then
		return
	end

	for _, transition in ipairs(transitions) do
		transition:stop()
	end

	self.active[owner] = nil
end

return TransitionManager
