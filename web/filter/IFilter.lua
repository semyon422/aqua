local class = require("class")

---@class web.IFilter
---@operator call: web.IFilter
local IFilter = class()

---@param size integer
---@return string?
---@return string?
function IFilter:receive(size) end

---@param data string
---@return integer?
---@return string?
function IFilter:send(data) end

function IFilter:close() end

return IFilter
