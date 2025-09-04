local class = require("class")

---@class ui.EffectMaskProvider
---@operator call: ui.EffectMaskProvider
---@field getWidth fun(): number
---@field getHeight fun(): number
---@field world_transform love.Transform
local EffectMaskProvider = class()

function EffectMaskProvider:drawEffectMask()
	love.graphics.draw("fill", 0, 0, self:getWidth(), self:getHeight())
end

return EffectMaskProvider
