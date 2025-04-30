local buffer = require("string.buffer")
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
	return buffer.encode(msg)
end

---@param s string
---@return icc.Message?
function WebsocketPeer:decode(s)
	local ok, msg = pcall(buffer.decode, s)
	if not ok then
		return
	end
	---@cast msg table
	return setmetatable(msg, Message)
end

---@param msg icc.Message
---@return integer?
---@return string?
function WebsocketPeer:send(msg)
	return self.ws:send("text", self:encode(msg))
end

return WebsocketPeer
