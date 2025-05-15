local buffer = require("string.buffer")
local IPeer = require("icc.IPeer")
local Message = require("icc.Message")

---@class icc.StringBufferPeer: icc.IPeer
---@operator call: icc.StringBufferPeer
local StringBufferPeer = IPeer + {}

---@param msg icc.Message
---@return string
function StringBufferPeer:encode(msg)
	return buffer.encode(msg)
end

---@param s string
---@return icc.Message?
function StringBufferPeer:decode(s)
	local ok, msg = pcall(buffer.decode, s)
	if not ok then
		return
	end
	---@cast msg table
	return setmetatable(msg, Message)
end

return StringBufferPeer
