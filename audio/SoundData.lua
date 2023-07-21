local class = require("class_new2")

local SoundData = class()

function SoundData:new(pointer, size) end
function SoundData:release() end
function SoundData:amplify(gain) end

return SoundData
