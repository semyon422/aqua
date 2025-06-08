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
	local data = self:encode(msg)
	self.peer:send(data)
	return #data
end

return EnetPeer
