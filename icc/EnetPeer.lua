local StringBufferPeer = require("icc.StringBufferPeer")

---@class icc.EnetPeer: icc.StringBufferPeer
---@operator call: icc.EnetPeer
local EnetPeer = StringBufferPeer + {}

---@param peer {send: function}
function EnetPeer:new(peer)
	self.peer = peer
end

---@param msg icc.Message
---@return integer?
---@return string?
function EnetPeer:send(msg)
	self.peer:send(self:encode(msg))
	return 1
end

return EnetPeer
