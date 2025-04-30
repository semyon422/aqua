local BassSource = require("audio.bass.BassSource")
local bit = require("bit")
local bass = require("bass")
local bass_assert = require("bass.assert")

---@class audio.bass.BassStream: audio.bass.BassSource
---@operator call:audio.bass.BassStream
local BassStream = BassSource + {}

function BassStream:new(path)
	local flags = 0x40000000 -- BASS_ASYNCFILE
	if jit.os == "Windows" then
		local winapi = require("winapi")
		path = winapi.to_wchar_t(path)
		flags = bit.bor(flags, 0x80000000) -- BASS_UNICODE
	end
	flags = bit.bor(flags, 0x20000) -- BASS_STREAM_PRESCAN

	self.channel = bass.BASS_StreamCreateFile(false, path, 0, 0, flags)
	bass_assert(self.channel ~= 0)
	self:readChannelInfo()
end

return BassStream
