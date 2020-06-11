local ffi = require("ffi")
local byte = require("byte")
local bass = require("aqua.audio.bass")
local Audio = require("aqua.audio.Audio")
local Timer = require("aqua.util.Timer")

local Stream = Audio:new()

Stream.construct = function(self)
	self.channel = bass.BASS_StreamCreateFile(false, self.path, 0, 0, 0)
	self.timer = Timer:new()
	self.timer.getAdjustTime = self.getAdjustTime
	self.timer.audio = self

	self:loadDataChannel()
end

Stream.loadData = function(self)
	local soundData = self.soundData

	self.byteBuffer = byte.buffer(soundData.fileData:getString(), 0, nil, true)
	self.info = soundData.info
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
	bass.BASS_StreamFree(self.channel)
end

return Stream
