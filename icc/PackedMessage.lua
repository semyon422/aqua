local class = require("class")

---@class icc.PackedMessage
---@field msg icc.Message
---@field sid any
local PackedMessage = class()

---@param msg icc.Message
---@param sid any
function PackedMessage:new(msg, sid)
	self.msg = msg
	self.sid = sid
end

return PackedMessage
