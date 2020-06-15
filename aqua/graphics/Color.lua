local Class = require("aqua.util.Class")

local major, minor, revision, codename = love.getVersion()

local Color = Class:new()

Color[1] = 0
Color[2] = 0
Color[3] = 0
Color[4] = 0

Color.get = function(self, norm)
    norm = norm or (major == 0 and 255 or 1)
    return self[1] * norm, self[2] * norm, self[3] * norm, self[4] * norm
end

Color.set = function(self, color, norm)
    norm = norm or (major == 0 and 255 or 1)
    self[1] = (color[1] or norm) / norm
    self[2] = (color[2] or norm) / norm
    self[3] = (color[3] or norm) / norm
    self[4] = (color[4] or norm) / norm
    return self
end

return Color
