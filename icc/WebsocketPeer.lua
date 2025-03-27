local json = require("web.json")
local IPeer = require("icc.IPeer")
local Message = require("icc.Message")

---@class icc.WebsocketPeer: icc.IPeer
---@operator call: icc.WebsocketPeer
local WebsocketPeer = IPeer + {}

---@param ws web.Websocket
function WebsocketPeer:new(ws)
	self.ws = ws
end

---@param msg icc.Message
---@return string
function WebsocketPeer:encode(msg)
	return json.encode({
		id = msg.id,
		ret = msg.ret,
		n = msg.n,
		args = {msg:unpack()},
	})
end

---@param s string
---@return icc.Message?
function WebsocketPeer:decode(s)
	local msg = json.decode_safe(s)
	if not msg then
		return
	end
	return Message(msg.id, msg.ret, unpack(msg.args, 1, msg.n))
end

---@param msg icc.Message
function WebsocketPeer:send(msg)
	return self.ws:send("text", self:encode(msg))
end

return WebsocketPeer
