local buffer = require("string.buffer")
local zlib = require("zlib")
local IPeer = require("icc.IPeer")
local Message = require("icc.Message")

---@class icc.StringBufferPeer: icc.IPeer
---@operator call: icc.StringBufferPeer
local StringBufferPeer = IPeer + {}

---@param msg icc.Message
---@return string
function StringBufferPeer:encode(msg)
	return zlib.deflate(buffer.encode(msg))
end

---@param s string
---@return icc.Message?
function StringBufferPeer:decode(s)
	local ok, data = pcall(zlib.inflate, s)
	if not ok then
		return
	end

	local ok, msg = pcall(buffer.decode, data)
	if not ok then
		return
	end

	---@cast msg table
	return setmetatable(msg, Message)
end

return StringBufferPeer
