local ffi = require("ffi")
local utf8 = require("utf8")

local _utf8 = {}

_utf8.validate = function(s, c)
    local size = #s
    local buffer = ffi.new("char[?]", size, s)
    local ptr = ffi.cast("char*", buffer)

    local len, pos = utf8.len(s)
    while not len do
        ptr[pos - 1] = c:byte()
        ptr = ptr + pos
        s = s:sub(pos + 1)
        len, pos = utf8.len(s)
    end

    return ffi.string(buffer, size)
end

return _utf8
