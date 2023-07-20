local class = require("class_new")

local SoundData, new = class()

function SoundData:new(pointer, size) end
function SoundData:release() end
function SoundData:amplify(gain) end

return new
