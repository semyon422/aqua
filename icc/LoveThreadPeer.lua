local IPeer = require("icc.IPeer")

---@class icc.LoveThreadPeer: icc.IPeer
---@operator call: icc.LoveThreadPeer
local LoveThreadPeer = IPeer + {}

---@param channel_name string
function LoveThreadPeer:new(channel_name)
	self.channel = love.thread.getChannel(channel_name)
end

---@param msg icc.Message
function LoveThreadPeer:send(msg)
	self.channel:push(msg)
end

return LoveThreadPeer
