local class = require("class")

---@class ui.ITransition
---@operator call: ui.ITransition
---@field get_value fun(): number | table
---@field set_value fun(v: number | table)
---@field is_completed boolean
local ITransition = class()

function ITransition:start() end

---@param dt number
function ITransition:update(dt) end

function ITransition:markCompleted() end

return ITransition
