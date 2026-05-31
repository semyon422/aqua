local IPeer = require("icc.IPeer")
local StringBufferPeer = require("icc.StringBufferPeer")

local nats_buffer = StringBufferPeer()

--- Publishes a single message to a NATS subject.
--- NATS fans out to all subscribers — the caller has zero knowledge of peer topology.
---@class icc.BroadcastingPeer: icc.IPeer
---@operator call: icc.BroadcastingPeer
local BroadcastingPeer = IPeer + {}

---@param nc nats.INats
---@param subject string
function BroadcastingPeer:new(nc, subject)
	self.nc = nc
	self.subject = subject
end

---@param msg icc.Message
---@return integer?, string?
function BroadcastingPeer:send(msg)
	local payload = nats_buffer:encode(msg)
	local ok, err = self.nc:publish({subject = self.subject, payload = payload})
	if not ok then return nil, err end
	return #payload
end

return BroadcastingPeer
