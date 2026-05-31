local IPeer = require("icc.IPeer")
local StringBufferPeer = require("icc.StringBufferPeer")

local nats_buffer = StringBufferPeer()

---@class icc.NatsPeer: icc.IPeer
---@field nc nats.INats NATS connection
---@field inbox string? NATS inbox subject prefix (nil for reply-only peers)
---@field target string target subject suffix (peer ID or reply_to)
---@operator call: icc.NatsPeer
local NatsPeer = IPeer + {}

---@param nc nats.INats NATS connection
---@param inbox string? NATS inbox subject prefix (e.g. "icc.inbox.{uuid}"), nil for reply-only
---@param target string target subject suffix (peer ID for calls, reply_to for responses)
function NatsPeer:new(nc, inbox, target)
	self.nc = nc
	self.inbox = inbox
	self.target = target
end

---@param msg icc.Message
---@return integer?
---@return string?
function NatsPeer:send(msg)
	local payload = nats_buffer:encode(msg)
	local subject = self.inbox and "icc.peer." .. self.target or self.target
	local opts = {
		subject = subject,
		payload = payload,
	}
	-- Two-way call: include reply_to so callee responds to our inbox
	if msg.id and self.inbox then
		opts.reply_to = self.inbox .. "." .. msg.id
	end
	local ok, err = self.nc:publish(opts)
	if not ok then
		return nil, err
	end
	return #payload
end

function NatsPeer:close()
end

return NatsPeer
