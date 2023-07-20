local class = require("class_new")
local BassSoundData = require("audio.bass.BassSoundData")
local StreamMemoryTempo = require("audio.bass.StreamMemoryTempo")
local Sample = require("audio.bass.Sample")
local bass = require("bass")

local audio = {}

audio.SoundData = class(BassSoundData, true)
audio.newSoundData = BassSoundData

function audio.newSource(soundData, _type)
	assert(soundData)
	if _type == "bass_fx_tempo" then
		return StreamMemoryTempo(soundData)
	end
	return Sample(soundData)
end

audio.init = bass.init
audio.reinit = bass.reinit

audio.default_dev_period = bass.default_dev_period
audio.default_dev_buffer = bass.default_dev_buffer
audio.setDevicePeriod = bass.setDevicePeriod
audio.setDeviceBuffer = bass.setDeviceBuffer

audio.getInfo = bass.getInfo

return audio
