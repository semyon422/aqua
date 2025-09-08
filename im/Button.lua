local class = require("class")

---@class im.Button
---@operator call: im.Button
local Button = class()

---@param state {active_id: any?}
---@param mouse_input im.MouseInput
function Button:new(state, mouse_input)
	self.state = state
	self.mouse_input = mouse_input
end

---@param id any?
---@param over boolean?
---@param index integer?
---@return integer? changed
---@return boolean? active
---@return boolean? hovered
function Button:button(id, over, index)
	local state = self.state
	local mouse_input = self.mouse_input

	index = index or next(mouse_input.pressed) or next(mouse_input.released)
	if mouse_input.pressed[index] and over then
		state.active_id = id
	end

	local same_id = rawequal(state.active_id, id)

	local down = mouse_input.down[index] or false
	local active = over and same_id and down or false
	local hovered = over and (same_id or not down) or false

	---@type any?
	local changed
	if same_id and not down then
		changed = over and same_id and index
		state.active_id = nil
	end

	if changed == false then
		changed = nil
	end

	return changed, active, hovered
end

return Button
