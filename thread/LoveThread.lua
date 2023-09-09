local class = require("class")

local codestring

---@param id number
---@return string
local function getCodeString(id)
	if not codestring then
		local path = "aqua/thread/threadcode.lua"
		codestring = love.filesystem.read(path)
	end
	return (codestring:gsub('"<threadId>"', id))
end

---@class thread.LoveThread
---@operator call: thread.LoveThread
local LoveThread = class()

---@param id number
function LoveThread:new(id)
	self.id = id

	self.thread = love.thread.newThread(getCodeString(id))

	self.inputChannel = love.thread.getChannel("input" .. id)
	self.outputChannel = love.thread.getChannel("output" .. id)

	self.inputChannel:clear()
	self.outputChannel:clear()
end

function LoveThread:start()
	self.thread:start()
end

---@return boolean
function LoveThread:isRunning()
	return self.thread:isRunning()
end

---@return string?
function LoveThread:getError()
	return self.thread:getError()
end

---@param event any
function LoveThread:push(event)
	self.inputChannel:push(event)
end

---@return any?
function LoveThread:pop()
	return self.outputChannel:pop()
end

return LoveThread
