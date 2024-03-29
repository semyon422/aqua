local BassSoundData = require("audio.bass.BassSoundData")
local StreamMemoryTempo = require("audio.bass.StreamMemoryTempo")
local Sample = require("audio.bass.Sample")
local BassStream = require("audio.bass.BassStream")
local bass = require("bass")

local audio = {}

audio.SoundData = BassSoundData

---@param soundData audio.bass.BassSoundData
---@param _type string?
---@return audio.bass.BassSource
function audio.newSource(soundData, _type)
	if _type == "bass_fx_tempo" then
		return StreamMemoryTempo(soundData)
	end
	return Sample(soundData)
end

---@param path string
---@return audio.bass.BassSource
function audio.newFileSource(path)
	return BassStream(path)
end

audio.init = bass.init
audio.reinit = bass.reinit

audio.default_dev_period = bass.default_dev_period
audio.default_dev_buffer = bass.default_dev_buffer
audio.setDevicePeriod = bass.setDevicePeriod
audio.setDeviceBuffer = bass.setDeviceBuffer

audio.getInfo = bass.getInfo

return audio
