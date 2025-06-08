local SoundData = require("audio.SoundData")

local audio = {}

audio.SoundData = SoundData

function audio.newSource(soundData, _type) end

function audio.init() end
function audio.reinit() end

audio.default_dev_period = 10
audio.default_dev_buffer = 10
function audio.setDevicePeriod(period) end -- in ms
function audio.setDeviceBuffer(buffer) end -- in ms

function audio.getInfo()
	return {
		latency = 0, -- in ms
	}
end

local impls = {
	empty = audio,
	bass = require("audio.bass"),
}

return impls.bass
