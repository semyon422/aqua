local StringBufferPeer = require("icc.StringBufferPeer")

---@class icc.WebsocketPeer: icc.StringBufferPeer
---@operator call: icc.WebsocketPeer
local WebsocketPeer = StringBufferPeer + {}

---@param ws web.Websocket
function WebsocketPeer:new(ws)
	self.ws = ws
end

---@param msg icc.Message
---@return integer?
---@return string?
function WebsocketPeer:send(msg)
	return self.ws:send("text", self:encode(msg))
end

return WebsocketPeer
