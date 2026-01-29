local ls = require("ls")
local ITestingIO = require("testing.ITestingIO")

---@type Socket?
local socket
do
	local ok, err = pcall(require, "socket")
	if ok then
		socket = err
	end
end

---@class testing.BaseTestingIO: testing.ITestingIO
---@operator call: testing.BaseTestingIO
local BaseTestingIO = ITestingIO + {}

---@type string[]
BaseTestingIO.blacklist = {}

---@param dir string
function BaseTestingIO:lookup(dir)
	for _, f in ipairs(self.blacklist) do
		if dir:find(f, 1, true) then
			return
		end
	end

	for name, t in ls.iter(dir) do
		local path = dir .. name
		if t == "file" then
			coroutine.yield(path)
		elseif t == "directory" then
			self:lookup(path .. "/")
		end
	end
end

---@param path string
---@return fun(): string?
function BaseTestingIO:iterFiles(path)
	return coroutine.wrap(function()
		self:lookup(path)
	end)
end

---@param path string
---@return any ...
function BaseTestingIO:dofile(path)
	return dofile(path)
end

---@param s string
function BaseTestingIO:writeStdout(s)
	io.write(s)
	io.flush()
end

---@return number
function BaseTestingIO:getTime()
	if love then
		return love.timer.getTime()
	end
	if socket then
		return socket.gettime()
	end
	return 0
end

return BaseTestingIO
