local ffi = require("ffi")
local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")

local Stream = Audio:new()

Stream.construct = function(self)
	if not self.path then
		return
	end
	self.channel = bass.BASS_StreamCreateFile(false, self.path, 0, 0, 0)

	self:loadDataChannel()
end

Stream.loadDataChannel = function(self)
	local info = ffi.new("BASS_CHANNELINFO")
	bass.BASS_ChannelGetInfo(self.channel, info)

	self.info = {
		freq = info.freq,
		chans = info.chans,
		flags = info.flags,
		ctype = info.ctype,
		origres = info.origres,
		plugin = info.plugin,
		sample = info.sample,
		filename = info.filename
	}
end

Stream.free = function(self)
	bass.BASS_ChannelFree(self.channel)
end

return Stream
