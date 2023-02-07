local just = require("just")
local imgui = require("imgui")
local audio = require("audio")
local bass = require("audio.bass")
local ffi = require("ffi")
local bass_assert = require("audio.bass_assert")

local callbacks = {
	"mousepressed",
	"mousereleased",
	"mousemoved",
	"wheelmoved",
	"keypressed",
	"keyreleased",
	"textinput",
}
for _, name in ipairs(callbacks) do
	love[name] = function(...)
		if just.callbacks[name](...) then return end
	end
end

local source
function love.load()
	local rate = 44100
	local t = 1
	local samples = math.floor(rate * t)

	local sample = bass.BASS_SampleCreate(samples * 2, rate, 1, 65535, 0)
	local buffer = ffi.new("int16_t[?]", samples)
	for i = 0, samples - 1 do
		buffer[i] = math.sin(2 * math.pi * 440 * i / rate) * 32767
	end
	bass_assert(bass.BASS_SampleSetData(sample, buffer) == 1)
	local soundData = audio.sampleToSoundData(sample)

	source = audio:newAudio(soundData)
end

function love.draw()
	imgui.setSize(400, 400, 200, 32)

	if imgui.button("btn1", "play") then
		source:play()
	end
	if imgui.button("btn2", "pause") then
		source:pause()
	end
	if imgui.button("btn3", "stop") then
		source:stop()
	end
	if imgui.button("btn4", "release") then
		source:release()
	end
	imgui.label("source time", source:getPosition())
	imgui.label("source status", bass.BASS_ChannelIsActive(source.channel))

	just._end()
end
