local class = require("class")

---@class audio.Source
---@operator call:audio.Source
local Source = class()

Source.rateValue = 1
Source.offset = 0
Source.baseVolume = 1

function Source:new() end

function Source:release() end

function Source:play() end
function Source:pause() end
function Source:stop() end

---@return boolean
function Source:isPlaying() return false end

---@param rate number
function Source:setRate(rate) end

---@param pitch number
function Source:setPitch(pitch) end

---@return number
function Source:getPosition() return 0 end

---@param position number
function Source:setPosition(position) end

---@return number
function Source:getDuration() return 0 end

---@param volume number
function Source:setBaseVolume(volume) end

---@param volume number
function Source:setVolume(volume) end

return Source
