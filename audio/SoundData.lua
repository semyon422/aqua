local class = require("class")

---@class audio.SoundData
---@operator call:audio.SoundData
local SoundData = class()

function SoundData:new(pointer, size) end
function SoundData:release() end
function SoundData:amplify(gain) end

function SoundData:getBitDepth() end
function SoundData:getChannelCount() end
function SoundData:getDuration() end
function SoundData:getSample(i, channel) end
function SoundData:getSampleCount() end
function SoundData:getSampleRate() end

return SoundData
