local BassSource = require("audio.bass.BassSource")
local bass = require("bass")
local bass_assert = require("bass.assert")

---@class audio.bass.BassStream: audio.bass.BassSource
---@operator call:audio.bass.BassStream
local BassStream = BassSource + {}

function BassStream:new(path)
	self.channel = bass.BASS_StreamCreateFile(false, path, 0, 0, 0)
	bass_assert(self.channel ~= 0)
	self:readChannelInfo()
end

return BassStream
