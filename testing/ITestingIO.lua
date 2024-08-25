local class = require("class")

---@class testing.ITestingIO
---@operator call: testing.ITestingIO
local ITestingIO = class()

---@param path string
---@return fun(): string?
function ITestingIO:iterFiles(path)
	return function() end
end

---@param path string
---@return any ...
function ITestingIO:dofile(path) end

---@param s string
function ITestingIO:writeStdout(s) end

---@return number
function ITestingIO:getTime()
	return 0
end

return ITestingIO
