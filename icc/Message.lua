local class = require("class")

---@class icc.Message
---@operator call: icc.Message
---@field id icc.EventId
---@field ret true?
---@field n integer
---@field [integer] any
local Message = class()

---@return any ...
function Message:unpack()
	return unpack(self, 1, self.n)
end

return Message
