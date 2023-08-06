local class = require("class_new2")

---@class audio.Source
---@operator call:audio.Source
local Source = class()

Source.rateValue = 1
Source.offset = 0
Source.baseVolume = 1

function Source:new(soundData) end
function Source:release() end

function Source:play() end
function Source:pause() end
function Source:stop() end

function Source:isPlaying() end
function Source:setRate(rate) end
function Source:setPitch(pitch) end
function Source:getPosition() end
function Source:setPosition(position) end
function Source:getDuration() end
function Source:setBaseVolume(volume) end
function Source:setVolume(volume) end

return Source
